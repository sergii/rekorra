# frozen_string_literal: true

# Real in-flight crash, authorized audited recovery, duplicate-key protection.
ENV["RAILS_ENV"] = "test"
require_relative "../dummy/config/environment"
require "fileutils"
require "securerandom"
require "rack/mock"
require "nokogiri"
STDOUT.sync = true

abort "Primary must be PostgreSQL" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
abort "Queue must be PostgreSQL" unless SolidQueue::Record.connection.adapter_name == "PostgreSQL"
abort "Separate databases required" if
  SolidQueue::Record.connection.select_value("SELECT current_database()") ==
    ActiveRecord::Base.connection.select_value("SELECT current_database()")
abort "Two worker processes required" unless ENV.fetch("REKORRA_WORKER_PROCESSES", "") == "2"

class RecoveryOperationsSmoke
  DEADLINE = 55

  def initialize
    @root = Rails.root
    @logs = @root.join("tmp/worker-recovery-operations")
    FileUtils.mkdir_p(@logs)
    @supervisor = nil
    @token = SecureRandom.hex(6)
    ENV["REKORRA_DEMO_PASSWORD"] = "recovery-operations-ci-only"
  end

  def call
    acme = Organization.find_or_create_by!(slug: "acme") { |o| o.name = "Acme" }
    globex = Organization.find_or_create_by!(slug: "globex") { |o| o.name = "Globex" }
    order = new_order(acme, "own")
    foreign = new_order(globex, "foreign")
    collision = new_order(acme, "collision")
    original = order.total_cents
    key = "receipt:#{@token}"
    probe = WorkerResilienceProbe.create!(token: "#{@token}-primary")
    job = WorkerIdempotentRecoveryJob.perform_later(probe.id, order.id, key, true)
    jid = job.job_id
    DemoJobLink.create!(order: order, active_job_id: jid,
      job_class_name: "WorkerIdempotentRecoveryJob",
      provider: "solid_queue", queue_name: "default")
    backend = SolidQueue::Job.find_by!(active_job_id: jid)
    check_status(order, jid, "Queued")
    launch

    wait_for("committed effect and matching claimed worker PID") do
      claim = SolidQueue::ClaimedExecution.find_by(job_id: backend.id)
      claimed_pid = SolidQueue::Process.find_by(id: claim.process_id)&.pid if claim
      probe.reload.execution_count == 1 && claim &&
        claimed_pid == probe.started_pid &&
        WorkerRecoveryEffect.exists?(organization_id: acme.id, idempotency_key: key) &&
        order.reload.total_cents == original + 7
    end
    killed_pid = probe.reload.started_pid
    check_status(order, jid, "Running")
    check(backend.reload.finished_at.nil?, "Job completed before crash")
    Process.kill("KILL", killed_pid)
    puts "SIGKILL: running worker #{killed_pid} after local committed effect"

    wait_for("supervisor failed crashed claimed job") do
      SolidQueue::FailedExecution.exists?(job_id: backend.id) &&
        SolidQueue::ClaimedExecution.where(job_id: backend.id).none?
    end
    check_status(order, jid, "Failed")
    health = WorkerRecoveryHealth.snapshot
    check(health.failed_count == 1 && health.registered_workers >= 1,
      "Incorrect aggregate failure/worker health")
    check(health.oldest_failure_age_seconds && health.oldest_failure_age_seconds >= 0,
      "Oldest failure age missing")
    puts "PASS: failed count and worker health observed without serialized errors"

    denied { WorkerRecoveryService.retry_failed!(actor: globex, order: order,
      job_id: jid, reason: "Different tenant may not approve") }
    denied { WorkerRecoveryService.retry_failed!(actor: acme, order: foreign,
      job_id: jid, reason: "Unlinked job must not pass") }
    denied { WorkerRecoveryService.retry_failed!(actor: acme, order: order,
      job_id: jid, reason: "short") }
    denied { WorkerRecoveryService.retry_failed!(actor: acme, order: order,
      job_id: "forged-123456789", reason: "No such authorized linked job") }
    check(WorkerRecoveryDecision.none?, "Rejected recovery persisted a decision")
    check_status(order, jid, "Failed")
    puts "PASS: tenant/record/ID and approval-reason guards denied forged recovery"

    decision = WorkerRecoveryService.retry_failed!(actor: acme, order: order,
      job_id: jid, reason: "Reviewed persisted effect, approved replay-safe job")
    check(decision.persisted? && decision.action == "retry_requested",
      "Missing durable operator approval")
    denied { WorkerRecoveryService.retry_failed!(actor: acme, order: order,
      job_id: jid, reason: "Duplicate approval must not execute twice") }

    wait_for("operator retry completed") do
      probe.reload.finished_at.present? && backend.reload.finished_at.present?
    end
    check(probe.execution_count == 2, "Expected two real executions")
    check(order.reload.total_cents == original + 7, "Duplicate business effect after retry")
    check(WorkerRecoveryEffect.where(organization_id: acme.id, idempotency_key: key).count == 1,
      "Duplicate idempotency ledger records")
    check(WorkerRecoveryDecision.where(active_job_id: jid).count == 1,
      "Approval audit should have one row")
    check_status(order, jid, "Finished")
    puts "PASS: two starts, one committed business effect, one audited approval"

    # A different ActiveJob with the same logical operation must not reapply it.
    duplicate = WorkerResilienceProbe.create!(token: "#{@token}-duplicate")
    dup_job = WorkerIdempotentRecoveryJob.perform_later(duplicate.id, order.id, key, false)
    wait_for("separate duplicate-key job completed") do
      duplicate.reload.finished_at.present? &&
        SolidQueue::Job.find_by(active_job_id: dup_job.job_id)&.finished_at.present?
    end
    check(order.reload.total_cents == original + 7,
      "Different ActiveJob reapplied same local business effect")

    begin
      WorkerRecoveryEffect.apply_once!(order_id: collision.id, key: key)
      raise "Key collision was accepted for a different record"
    rescue WorkerRecoveryEffect::KeyCollision
      # Key is not reusable for another record under the same tenant.
    end
    check(collision.reload.total_cents == 10, "Collision changed another order")
    check(WorkerRecoveryEffect.apply_once!(order_id: foreign.id, key: key) == :applied,
      "Equal key should be independently scoped to another tenant")
    check(foreign.reload.total_cents == 17, "Cross-tenant namespace not applied")
    check(WorkerRecoveryEffect.where(idempotency_key: key).count == 2,
      "Expected separate tenant-key ledger rows")
    check(WorkerRecoveryHealth.snapshot.failed_count == 0,
      "Failed queue count not cleared after successful retry")
    puts "PASS: duplicate job protected; key collisions rejected; tenant keys isolated"
  ensure
    shutdown
  end

  private

  def new_order(organization, label)
    customer = Customer.create!(organization: organization,
      name: "#{label} #{@token}",
      email: "#{label}-#{@token}@worker.test")
    Order.create!(customer: customer, number: "RECOVERY-#{label}-#{@token}",
      status: "pending", total_cents: 10)
  end

  def check_status(order, jid, expected)
    basic = ActionController::HttpAuthentication::Basic.encode_credentials(
      "acme", ENV.fetch("REKORRA_DEMO_PASSWORD"))
    result = Rack::MockRequest.new(Rails.application).get(
      "/backoffice/resources/orders/#{order.id}",
      "HTTP_HOST" => "localhost", "HTTP_AUTHORIZATION" => basic)
    check(result.status == 200, "Rekorra HTTP #{result.status}")
    row = Nokogiri::HTML(result.body).css("section.rk-jobs li.rk-jobs__item")
      .find { |node| node.text.include?(jid) }
    check(row, "Linked job not visible")
    check(row.css(".rk-badge").text.strip == expected, "Expected status #{expected}")
  end

  def denied
    yield
    raise "Unauthorized recovery accepted"
  rescue WorkerRecoveryService::Rejected
    true
  end

  def launch
    log = @logs.join("supervisor.log")
    @supervisor = Process.spawn({ "RAILS_ENV" => "test" },
      "bundle", "exec", "rake", "solid_queue:start",
      chdir: @root.to_s, out: log.to_s, err: log.to_s, pgroup: true)
    puts "Started supervisor pid=#{@supervisor}"
  end

  def wait_for(label)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + DEADLINE
    until yield
      exited, status = Process.waitpid2(@supervisor, Process::WNOHANG)
      raise "#{label}: supervisor exited #{status.inspect}" if exited
      raise "#{label}: timeout #{DEADLINE}s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.2
    end
    puts "Observed #{label}"
  rescue StandardError
    @logs.children.each do |file|
      lines = File.readlines(file)
      warn "--- #{file.basename} error signatures ---"
      warn lines.grep(/ERROR|FATAL|PG::|Exception|ActiveRecord::|ProcessExitError/i).first(30).join
      warn "--- #{file.basename} tail ---"
      warn lines.last(70).join
    end
    raise
  end

  def shutdown
    return unless @supervisor
    Process.kill("TERM", -@supervisor)
    Process.waitpid(@supervisor)
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  end

  def check(value, message)
    raise message unless value
  end
end

RecoveryOperationsSmoke.new.call

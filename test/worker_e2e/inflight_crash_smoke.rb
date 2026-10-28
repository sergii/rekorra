# frozen_string_literal: true

# Separate from ordinary rake test and the queued-backlog resilience test.
# Proves a genuinely claimed job is FAILED by Solid Queue after child SIGKILL,
# and a human/operator-style FailedExecution#retry explicitly re-enqueues it.
ENV["RAILS_ENV"] = "test"
require_relative "../dummy/config/environment"
require "fileutils"
require "securerandom"
require "rack/mock"
require "nokogiri"

STDOUT.sync = true
abort "PostgreSQL primary required" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
abort "PostgreSQL queue required" unless SolidQueue::Record.connection.adapter_name == "PostgreSQL"
abort "Independent PostgreSQL queue required" if
  SolidQueue::Record.connection.select_value("SELECT current_database()") ==
    ActiveRecord::Base.connection.select_value("SELECT current_database()")
abort "Two forked workers required" unless ENV.fetch("REKORRA_WORKER_PROCESSES", "") == "2"

class InFlightCrashSmoke
  DEADLINE = 55

  def initialize
    @root = Rails.root
    @logs = @root.join("tmp/worker-inflight-crash")
    FileUtils.mkdir_p(@logs)
    @supervisor = nil
    @token = SecureRandom.hex(6)
    ENV["REKORRA_DEMO_PASSWORD"] = "inflight-crash-ci-only"
  end

  def call
    acme = Organization.find_or_create_by!(slug: "acme") { |org| org.name = "Acme" }
    customer = Customer.create!(organization: acme, name: "In-flight #{@token}",
      email: "inflight-#{@token}@worker.test")
    order = Order.create!(customer: customer, number: "INFLIGHT-#{@token}",
      status: "pending", total_cents: 10)
    probe = WorkerResilienceProbe.create!(token: @token)
    active_job = WorkerInFlightCrashJob.perform_later(probe.id)
    check(active_job.job_id.present?, "Missing ActiveJob ID")
    DemoJobLink.create!(order: order, active_job_id: active_job.job_id,
      job_class_name: "WorkerInFlightCrashJob", provider: "solid_queue",
      queue_name: "default")
    job = SolidQueue::Job.find_by!(active_job_id: active_job.job_id)
    check(probe.reload.started_at.nil?, "Job started without worker")
    check_status(order, active_job.job_id, "Queued")

    launch
    claimed = nil
    wait_for("persisted claim AND business start on the same worker") do
      claimed = SolidQueue::ClaimedExecution.find_by(job_id: job.id)
      started = probe.reload
      claimed && started.execution_count == 1 && started.started_at.present? &&
        SolidQueue::Process.find_by(id: claimed.process_id)&.pid == started.started_pid
    end

    worker_pid = probe.reload.started_pid
    check(Process.kill(0, worker_pid) == 1, "Claimed worker PID not alive")
    check(job.reload.finished_at.nil?, "Job completed before SIGKILL")
    check_status(order, active_job.job_id, "Running")
    puts "IN-FLIGHT: job_id=#{active_job.job_id}, claimed worker_pid=#{worker_pid}, attempt=1"

    # Do not kill the supervisor: it must detect this *child* exiting, fail
    # the claimed job, and launch a replacement worker.
    Process.kill("KILL", worker_pid)
    puts "SIGKILL: running worker pid=#{worker_pid}"

    failure = nil
    wait_for("supervisor marks in-flight execution failed") do
      failure = SolidQueue::FailedExecution.find_by(job_id: job.id)
      failure && SolidQueue::ClaimedExecution.where(job_id: job.id).none?
    end
    check(failure.exception_class == "SolidQueue::Processes::ProcessExitError",
      "Unexpected failure type #{failure.exception_class.inspect}")
    check(probe.reload.execution_count == 1 && probe.finished_at.nil?,
      "Killed job committed a completed effect")
    check_status(order, active_job.job_id, "Failed")
    puts "PASS: killed claimed job marked Failed with ProcessExitError and shown by Rekorra"

    wait_for("replacement worker registered") do
      SolidQueue::Process.where(kind: "Worker").where.not(pid: worker_pid).count >= 2
    end
    # A failed claimed job must not be auto-requeued merely because the
    # replacement process exists. It requires an explicit recovery action.
    sleep 1.0
    check(probe.reload.execution_count == 1 && probe.finished_at.nil?,
      "Failed job unexpectedly reran automatically")
    check(SolidQueue::ReadyExecution.where(job_id: job.id).none?,
      "Failed job unexpectedly returned to ready queue")
    check(SolidQueue::ClaimedExecution.where(job_id: job.id).none?,
      "Failed job unexpectedly claimed again")
    puts "PASS: replacement worker running; failed execution NOT auto-retried"

    # This is the public Solid Queue API for an explicit operator retry,
    # not direct mutation of queue records or synthetic successful status.
    failure.retry
    puts "MANUAL RETRY: FailedExecution#retry invoked"
    wait_for("explicit retry finishes work") do
      probe.reload.finished_at.present? && job.reload.finished_at.present?
    end
    check(probe.reload.execution_count == 2,
      "Expected two durable starts after operator retry, got #{probe.execution_count}")
    check(probe.started_pid != worker_pid, "Killed worker completed retry")
    check(SolidQueue::FailedExecution.where(job_id: job.id).none?,
      "Failed execution not cleared by official retry")
    check(SolidQueue::ClaimedExecution.where(job_id: job.id).none?,
      "Claim stuck after successful retry")
    check_status(order, active_job.job_id, "Finished")

    puts "PASS: official retry finished on new worker PID=#{probe.started_pid}"
    puts "PASS: durable attempt_count=2 demonstrates at-least-once side-effect risk; no exactly-once claim"
  ensure
    shutdown
  end

  private

  def check_status(order, job_id, expected)
    auth = ActionController::HttpAuthentication::Basic.encode_credentials(
      "acme", ENV.fetch("REKORRA_DEMO_PASSWORD"))
    response = Rack::MockRequest.new(Rails.application).get(
      "/backoffice/resources/orders/#{order.id}",
      "HTTP_HOST" => "localhost", "HTTP_AUTHORIZATION" => auth)
    check(response.status == 200, "Rekorra returned HTTP #{response.status}")
    doc = Nokogiri::HTML(response.body)
    row = doc.css("section.rk-jobs li.rk-jobs__item").find { |node|
      node.text.include?(job_id)
    }
    check(row, "Missing job status row")
    actual = row.css(".rk-badge").text.strip
    check(actual == expected, "Expected Rekorra status #{expected}, got #{actual.inspect}")
  end

  def launch
    path = @logs.join("supervisor.log")
    @supervisor = Process.spawn({ "RAILS_ENV" => "test" },
      "bundle", "exec", "rake", "solid_queue:start",
      chdir: @root.to_s, out: path.to_s, err: path.to_s, pgroup: true)
    puts "Started Solid Queue supervisor pid=#{@supervisor}"
  end

  def wait_for(label)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + DEADLINE
    until yield
      exited, status = Process.waitpid2(@supervisor, Process::WNOHANG)
      raise "#{label}: supervisor exited #{status.inspect}" if exited
      raise "#{label}: exceeded #{DEADLINE}s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.2
    end
    puts "Observed #{label}"
  rescue StandardError
    @logs.children.each do |file|
      lines = File.readlines(file)
      warn "--- #{file.basename} first errors ---"
      warn lines.grep(/ERROR|FATAL|PG::|ActiveRecord::|Exception|ProcessExitError|failed/i).first(30).join
      warn "--- #{file.basename} tail ---"
      warn lines.last(90).join
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

InFlightCrashSmoke.new.call

# frozen_string_literal: true

# External delivery proof: a separate HTTP process commits to an independent
# PostgreSQL database, then deliberately dies before it can acknowledge.
ENV["RAILS_ENV"] = "test"
require_relative "../dummy/config/environment"
require "pg"
require "fileutils"
require "securerandom"
require "timeout"

STDOUT.sync = true
abort "PostgreSQL primary required" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
abort "PostgreSQL queue required" unless SolidQueue::Record.connection.adapter_name == "PostgreSQL"
abort "Queue must be an independent database" if
  SolidQueue::Record.connection.select_value("SELECT current_database()") ==
    ActiveRecord::Base.connection.select_value("SELECT current_database()")

class WorkerOutboxSmoke
  DEADLINE = 45

  def initialize
    @root = Rails.root
    @logs = @root.join("tmp/worker-outbox")
    FileUtils.mkdir_p(@logs)
    @port_file = @logs.join("provider.port")
    @provider = nil
    @worker = nil
    @token = SecureRandom.hex(6)
    @external = PG.connect(ENV.fetch("REKORRA_EXTERNAL_DATABASE_URL"))
  end

  def call
    @external.exec(<<~SQL)
      CREATE TABLE IF NOT EXISTS provider_receipts (
        operation_key TEXT PRIMARY KEY,
        receipt TEXT NOT NULL,
        requests INTEGER NOT NULL,
        ack_dropped BOOLEAN NOT NULL DEFAULT FALSE
      )
    SQL

    acme = Organization.find_or_create_by!(slug: "acme") { |o| o.name = "Acme" }
    customer = Customer.create!(organization: acme, name: "Outbox #{@token}",
      email: "outbox-#{@token}@worker.test")
    order = Order.create!(customer: customer, number: "OUTBOX-#{@token}",
      status: "pending", total_cents: 10)
    other = Order.create!(customer: customer, number: "OUTBOX-OTHER-#{@token}",
      status: "pending", total_cents: 10)

    rollback_key = "outbox:rollback:#{@token}"
    Order.transaction do
      WorkerOutboxOperation.apply_once!(order_id: order.id, key: rollback_key)
      raise ActiveRecord::Rollback
    end
    check(order.reload.total_cents == 10, "Rolled-back local effect committed")
    check(WorkerRecoveryEffect.where(idempotency_key: rollback_key).none?,
      "Rolled-back idempotency marker committed")
    check(WorkerOutboxEvent.where(operation_key: rollback_key).none?,
      "Outbox intent committed without business transaction")
    puts "PASS: rollback removes business effect, idempotency marker and outbox intent atomically"

    key_a = "outbox:delivery:#{@token}"
    result, event_a = WorkerOutboxOperation.apply_once!(order_id: order.id, key: key_a)
    check(result == :applied && order.reload.total_cents == 17, "First atomic operation incorrect")
    repeated, same_event = WorkerOutboxOperation.apply_once!(order_id: order.id, key: key_a)
    check(repeated == :already_applied && same_event.id == event_a.id, "Duplicate created another outbox event")
    check(order.reload.total_cents == 17, "Duplicate applied local effect twice")
    begin
      WorkerOutboxOperation.apply_once!(order_id: other.id, key: key_a)
      raise "Key collision permitted for another order"
    rescue WorkerRecoveryEffect::KeyCollision, WorkerOutboxOperation::KeyCollision
      check(other.reload.total_cents == 10, "Key collision changed another order")
    end
    puts "PASS: tenant-scoped key enforces single local mutation and outbox event"

    launch_provider(crash_key: external_key(event_a))
    launch_worker
    job_a = WorkerOutboxDeliveryJob.perform_later(event_a.id, @port_file.to_s)
    backend_a = SolidQueue::Job.find_by!(active_job_id: job_a.job_id)
    wait_for("provider committed but the first HTTP acknowledgment was lost") do
      receipt_count(external_key(event_a)) == 1 &&
        SolidQueue::FailedExecution.exists?(job_id: backend_a.id) &&
        event_a.reload.status == "unknown"
    end
    check(event_a.reload.attempts == 1 && event_a.delivered_at.nil?,
      "Lost acknowledgment was incorrectly treated as successful")
    check(provider_requests(external_key(event_a)) == 1, "Unexpected first request count")
    puts "PASS: remote provider effect committed, but outbox is UNKNOWN and queue job Failed"

    stop_provider
    launch_provider(crash_key: "none")
    SolidQueue::FailedExecution.find_by!(job_id: backend_a.id).retry
    wait_for("retry delivered previously committed provider effect") do
      event_a.reload.delivered? && backend_a.reload.finished_at.present?
    end
    check(provider_requests(external_key(event_a)) == 2,
      "Provider did not receive at-least-once re-delivery")
    check(receipt_count(external_key(event_a)) == 1, "Provider applied a duplicate effect")
    check(event_a.attempts == 2, "Unexpected outbox retry attempt count")
    check(WorkerOutboxDelivery.deliver!(event_id: event_a.id, endpoint: endpoint) == :already_delivered,
      "Delivered event should be a no-op")
    check(provider_requests(external_key(event_a)) == 2, "Delivered event re-sent")
    puts "PASS: manual retry re-sent the SAME key, provider deduplicated two deliveries into one effect"

    key_b = "outbox:reconcile:#{@token}"
    _, event_b = WorkerOutboxOperation.apply_once!(order_id: other.id, key: key_b)
    check(other.reload.total_cents == 17, "Reconciliation business effect missing")
    stop_provider
    launch_provider(crash_key: external_key(event_b))
    job_b = WorkerOutboxDeliveryJob.perform_later(event_b.id, @port_file.to_s)
    backend_b = SolidQueue::Job.find_by!(active_job_id: job_b.job_id)
    wait_for("second remote effect committed without acknowledgment") do
      receipt_count(external_key(event_b)) == 1 &&
        SolidQueue::FailedExecution.exists?(job_id: backend_b.id) &&
        event_b.reload.status == "unknown"
    end
    stop_provider
    launch_provider(crash_key: "none")
    result = WorkerOutboxDelivery.reconcile!(event_id: event_b.id, endpoint: endpoint)
    check(result == :reconciled && event_b.reload.delivered?, "Reconciliation failed")
    check(provider_requests(external_key(event_b)) == 1,
      "Read-only reconciliation unexpectedly redelivered provider effect")
    # The queue job is still Failed even though external reconciliation succeeded.
    check(SolidQueue::FailedExecution.exists?(job_id: backend_b.id),
      "Reconciliation forged a successful queue job")
    SolidQueue::FailedExecution.find_by!(job_id: backend_b.id).retry
    wait_for("no-op replay cleared backend failure after reconciliation") do
      backend_b.reload.finished_at.present? &&
        SolidQueue::FailedExecution.where(job_id: backend_b.id).none?
    end
    check(provider_requests(external_key(event_b)) == 1,
      "Recovered delivery status caused duplicate external traffic")
    puts "PASS: GET reconciliation confirmed remote receipt without POST; backend retry became a no-op"

    health = WorkerOutboxHealth.snapshot
    check(health.pending_count == 0 && health.unknown_count == 0 && health.delivered_count == 2,
      "Incorrect aggregate outbox health")
    check(WorkerOutboxEvent.where(organization_id: acme.id).count == 2,
      "Unexpected tenant outbox event count")
    check(receipt_count(nil) == 2 && order.reload.total_cents == 17 &&
      other.reload.total_cents == 17, "Lost or duplicated business effects")
    puts "PASS: 2 local effects, 2 remote effects, 2 delivered outbox intents and zero unknowns"
  ensure
    shutdown
  end

  private

  def external_key(event)
    "#{event.organization_id}:#{event.operation_key}"
  end

  def receipt_count(key)
    if key
      @external.exec_params("SELECT COUNT(*) FROM provider_receipts WHERE operation_key = $1", [key])[0]["count"].to_i
    else
      @external.exec("SELECT COUNT(*) FROM provider_receipts")[0]["count"].to_i
    end
  end

  def provider_requests(key)
    @external.exec_params("SELECT requests FROM provider_receipts WHERE operation_key = $1", [key])[0].fetch("requests").to_i
  end

  def endpoint
    "http://127.0.0.1:#{Integer(File.read(@port_file))}"
  end

  def launch_provider(crash_key:)
    FileUtils.rm_f(@port_file)
    path = @logs.join("provider-#{crash_key == 'none' ? 'normal' : 'crash'}-#{Process.clock_gettime(Process::CLOCK_MONOTONIC).to_i}.log")
    @provider = Process.spawn({
      "REKORRA_EXTERNAL_DATABASE_URL" => ENV.fetch("REKORRA_EXTERNAL_DATABASE_URL"),
      "REKORRA_PROVIDER_PORT_FILE" => @port_file.to_s,
      "REKORRA_PROVIDER_CRASH_KEY" => crash_key
    }, "bundle", "exec", "ruby", @root.parent.parent.join("test/worker_e2e/outbox_provider.rb").to_s,
      chdir: @root.to_s, out: path.to_s, err: path.to_s, pgroup: true)
    wait_for("independent provider listening") { @port_file.exist? && Integer(File.read(@port_file)) > 0 }
    puts "Started remote HTTP provider pid=#{@provider}, endpoint=#{endpoint}"
  end

  def launch_worker
    log = @logs.join("solid-worker.log")
    @worker = Process.spawn({ "RAILS_ENV" => "test" },
      "bundle", "exec", "rake", "solid_queue:start",
      chdir: @root.to_s, out: log.to_s, err: log.to_s, pgroup: true)
    puts "Started real Solid Queue supervisor #{@worker}"
  end

  def stop_provider
    return unless @provider
    Process.kill("TERM", @provider)
    Process.waitpid(@provider)
  rescue Errno::ECHILD, Errno::ESRCH
    nil
  ensure
    @provider = nil
  end

  def shutdown
    stop_provider
    if @worker
      Process.kill("TERM", -@worker) rescue nil
      Timeout.timeout(15) { Process.waitpid(@worker) } rescue nil
    end
    @external&.close
  end

  def wait_for(label)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + DEADLINE
    until yield
      if @worker
        pid, status = Process.waitpid2(@worker, Process::WNOHANG)
        raise "#{label}: worker supervisor exited #{status.inspect}" if pid
      end
      raise "#{label}: timeout after #{DEADLINE}s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.2
    end
    puts "Observed #{label}"
  rescue StandardError
    @logs.children.each do |file|
      next unless file.file?
      lines = File.readlines(file)
      warn "--- #{file.basename}: errors ---"
      warn lines.grep(/ERROR|FATAL|PG::|Exception|delivery|failed/i).first(25).join
      warn "--- #{file.basename}: tail ---"
      warn lines.last(50).join
    end
    raise
  end

  def check(value, message)
    raise message unless value
  end
end

WorkerOutboxSmoke.new.call

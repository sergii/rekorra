# frozen_string_literal: true

# Postgres primary + independent provider DB + two competing scanner processes.
ENV["RAILS_ENV"] = "test"
require_relative "../dummy/config/environment"
require "pg"
require "fileutils"
require "securerandom"
require "timeout"

STDOUT.sync = true
abort "PostgreSQL primary required" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
abort "PostgreSQL queue required" unless SolidQueue::Record.connection.adapter_name == "PostgreSQL"
abort "Independent queue required" if SolidQueue::Record.connection.select_value("SELECT current_database()") ==
  ActiveRecord::Base.connection.select_value("SELECT current_database()")

class OutboxDispatchSmoke
  DEADLINE = 35

  def initialize
    @root = Rails.root
    @logs = @root.join("tmp/worker-outbox-dispatch")
    FileUtils.mkdir_p(@logs)
    @port_file = @logs.join("provider.port")
    @external = PG.connect(ENV.fetch("REKORRA_EXTERNAL_DATABASE_URL"))
    @provider = nil
    @children = []
    @token = SecureRandom.hex(6)
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
    globex = Organization.find_or_create_by!(slug: "globex") { |o| o.name = "Globex" }
    customer = Customer.create!(organization: acme, name: "Dispatch #{@token}",
      email: "dispatch-#{@token}@worker.test")
    order = Order.create!(customer: customer, number: "DISPATCH-#{@token}",
      status: "pending", total_cents: 10)

    begin
      WorkerOutboxDispatcher.new(endpoint: "http://example.com:80",
        allowed_hosts: ["example.com"])
      raise "Untrusted plain HTTP permitted"
    rescue WorkerOutboxDispatcher::UnsafeEndpoint
      puts "PASS: untrusted plain HTTP provider rejected"
    end
    # 12 intents exist only in the primary DB. No queue jobs were enqueued.
    bulk = 12.times.map { |i|
      WorkerOutboxOperation.apply_once!(order_id: order.id,
        key: "dispatch:bulk:#{@token}:#{i}").last
    }
    check(order.reload.total_cents == 94, "Atomic local effect lost")
    check(bulk.all? { |e| e.status == "pending" }, "Outbox unexpectedly pre-delivered")
    launch_provider(crash_key: "none")
    dispatcher = make_dispatcher
    run_two_dispatchers("concurrent")
    check(bulk.all? { |e| e.reload.delivered? }, "Concurrent scanners failed to drain")
    pids = bulk.map { |e| e.reload.last_dispatcher_pid }.uniq
    check(pids.size == 2, "Two OS dispatchers must each claim jobs: #{pids.inspect}")
    check(bulk.all? { |e| requests(key_for(e)) == 1 },
      "Duplicate HTTP deliveries under two concurrent scanners")
    puts "PASS: 12 atomic intents discovered without Solid Queue enqueue; two real scanner PIDs delivered once each"

    # Kill a scanner AFTER an atomic lease, before any HTTP request.
    leased = WorkerOutboxOperation.apply_once!(order_id: order.id,
      key: "dispatch:leased:#{@token}").last
    holder = spawn_scanner("held", { "REKORRA_DISPATCH_HOLD_AFTER_CLAIM" => "1" })
    wait_for("held lease persisted") do
      leased.reload.lease_token.present? && leased.last_dispatcher_pid == holder
    end
    token = leased.lease_token
    Process.kill("KILL", holder)
    Process.waitpid(holder)
    @children.delete(holder)
    check(dispatcher.dispatch_once! == :idle, "Another dispatcher stole unexpired lease")
    check(requests(key_for(leased)) == 0, "Killed process sent a provider request")
    sleep 2.15
    run_two_dispatchers("lease-recovery")
    check(leased.reload.delivered? && requests(key_for(leased)) == 1,
      "Expired lease not recovered after scanner SIGKILL")
    check(leased.last_dispatcher_pid != holder, "Killed lease owner completed delivery")
    check(WorkerOutboxDelivery.deliver!(event_id: leased.id, endpoint: endpoint,
      lease_token: token) == :lease_lost, "Old lease token could mutate delivery state")
    puts "PASS: SIGKILLed dispatcher left durable lease; reclaim after expiry and stale-token fencing succeeded"

    # Remote DB commit followed by lost response: scanners reconcile UNKNOWN.
    unknown = WorkerOutboxOperation.apply_once!(order_id: order.id,
      key: "dispatch:unknown:#{@token}").last
    stop_provider
    launch_provider(crash_key: key_for(unknown))
    dispatcher = make_dispatcher
    check(dispatcher.dispatch_once! == :uncertain, "Expected lost-ACK uncertainty")
    check(unknown.reload.status == "unknown" && requests(key_for(unknown)) == 1,
      "Lost-ACK side effect must be committed and UNKNOWN")
    stop_provider
    launch_provider(crash_key: "none")
    dispatcher = make_dispatcher
    sleep 1.15
    check(dispatcher.dispatch_once! == :reconciled, "Unknown event not reconciled")
    check(unknown.reload.delivered? && requests(key_for(unknown)) == 1,
      "Receipt reconciliation must not POST again")
    puts "PASS: remote commit-before-ACK-loss recovered by read-only reconciliation, no duplicate POST"

    # No provider: exponential backoff and bounded attempts become review.
    failure = WorkerOutboxOperation.apply_once!(order_id: order.id,
      key: "dispatch:review:#{@token}").last
    stop_provider
    3.times do |i|
      outcome = dispatcher.dispatch_once!(now: Time.current + i * 10)
      check(outcome == :uncertain, "Expected uncertainty on provider outage, got #{outcome}")
    end
    check(failure.reload.status == "needs_review" && failure.dispatch_attempts == 3,
      "Terminal review gate not reached after bounded dispatch attempts")
    check(dispatcher.dispatch_once!(now: Time.current + 100) == :idle,
      "Dead-letter event must not auto-send")
    health = WorkerOutboxHealth.snapshot
    check(health.needs_review_count == 1 && health.delivered_count == 14 &&
      health.unknown_count == 0, "Incorrect operator health snapshot")
    puts "PASS: bounded backoff stops at needs_review; host-only aggregate health reports review"

    begin
      WorkerOutboxReview.reopen!(event: failure, actor: globex,
        reason: "Foreign tenant cannot approve this delivery")
      raise "Foreign tenant recovery accepted"
    rescue WorkerOutboxReview::Rejected
      nil
    end
    begin
      WorkerOutboxReview.reopen!(event: failure, actor: acme, reason: "short")
      raise "Short operator reason accepted"
    rescue WorkerOutboxReview::Rejected
      nil
    end
    check(WorkerOutboxReviewDecision.none?, "Rejected review persisted an audit entry")
    WorkerOutboxReview.reopen!(event: failure, actor: acme,
      reason: "Inspected provider state and approved re-delivery")
    check(WorkerOutboxReviewDecision.where(worker_outbox_event_id: failure.id).count == 1,
      "Approved review missing durable audit")
    check(failure.reload.status == "unknown" && failure.dispatch_attempts == 0,
      "Review failed to reset bounded attempts")
    launch_provider(crash_key: "none")
    dispatcher = make_dispatcher
    check(dispatcher.dispatch_once! == :delivered && failure.reload.delivered?,
      "Approved operator recovery did not deliver")
    check(requests(key_for(failure)) == 1, "Review recovery duplicated provider effect")
    puts "PASS: policy-gated, tenant-scoped operator review audited and resumed safe delivery"
    check(WorkerOutboxHealth.snapshot.delivered_count == 15, "Final outbox count incorrect")
    check(receipt_count == 15, "Provider lost or duplicated an external effect")
    puts "PASS: 15/15 local intents delivered, 15 distinct external effects, zero outstanding unknown/review"
  ensure
    shutdown
  end

  private

  def key_for(event)
    "#{event.organization_id}:#{event.operation_key}"
  end

  def receipt_count
    @external.exec("SELECT COUNT(*) FROM provider_receipts")[0].fetch("count").to_i
  end

  def requests(key)
    result = @external.exec_params("SELECT requests FROM provider_receipts WHERE operation_key = $1", [key])
    result.ntuples.zero? ? 0 : result[0].fetch("requests").to_i
  end

  def endpoint
    "http://127.0.0.1:#{Integer(File.read(@port_file))}"
  end

  def make_dispatcher
    WorkerOutboxDispatcher.new(endpoint: endpoint, allowed_hosts: [],
      allow_test_http: true)
  end

  def spawn_scanner(name, env = {})
    file = @logs.join("#{name}-#{SecureRandom.hex(3)}.log")
    pid = Process.spawn({
      "REKORRA_DISPATCH_ENDPOINT" => endpoint,
      "RAILS_ENV" => "test"
    }.merge(env), "bundle", "exec", "ruby",
      @root.parent.parent.join("test/worker_e2e/outbox_dispatcher_process.rb").to_s,
      chdir: @root.to_s, out: file.to_s, err: file.to_s, pgroup: true)
    @children << pid
    pid
  end

  def run_two_dispatchers(label)
    barrier = @logs.join("#{label}.go")
    FileUtils.rm_f(barrier)
    @logs.glob("#{label}.go.*").each { |path| FileUtils.rm_f(path) }
    first = spawn_scanner("#{label}-one", { "REKORRA_DISPATCH_BARRIER" => barrier.to_s })
    second = spawn_scanner("#{label}-two", { "REKORRA_DISPATCH_BARRIER" => barrier.to_s })
    wait_for("two scanner processes ready for #{label}") do
      @logs.glob("#{label}.go.*").size == 2
    end
    File.write(barrier, "go")
    [first, second].each do |pid|
      deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + DEADLINE
      loop do
        actual, status = Process.waitpid2(pid, Process::WNOHANG)
        if actual
          @children.delete(pid)
          check(status.success?, "Dispatcher #{pid} failed (#{status.inspect})")
          break
        end
        raise "Dispatcher #{pid} hung" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
        sleep 0.1
      end
    end
  end

  def launch_provider(crash_key:)
    FileUtils.rm_f(@port_file)
    log = @logs.join("provider-#{SecureRandom.hex(4)}.log")
    @provider = Process.spawn({
      "REKORRA_EXTERNAL_DATABASE_URL" => ENV.fetch("REKORRA_EXTERNAL_DATABASE_URL"),
      "REKORRA_PROVIDER_PORT_FILE" => @port_file.to_s,
      "REKORRA_PROVIDER_CRASH_KEY" => crash_key
    }, "bundle", "exec", "ruby",
      @root.parent.parent.join("test/worker_e2e/outbox_provider.rb").to_s,
      chdir: @root.to_s, out: log.to_s, err: log.to_s, pgroup: true)
    wait_for("HTTP provider startup") { @port_file.exist? && File.read(@port_file).to_i > 0 }
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

  def wait_for(label)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + DEADLINE
    until yield
      raise "#{label} timed out" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.1
    end
  rescue StandardError
    @logs.children.select(&:file?).each do |file|
      lines = File.readlines(file)
      warn "--- #{file.basename}: errors ---"
      warn lines.grep(/ERROR|FATAL|PG::|Exception|failed/i).first(12).join
      warn "--- #{file.basename}: last 30 ---"
      warn lines.last(30).join
    end
    raise
  end

  def check(value, message)
    raise message unless value
  end

  def shutdown
    @children.each do |pid|
      Process.kill("KILL", -pid) rescue nil
      Process.waitpid(pid) rescue nil
    end
    stop_provider
    @external&.close
  end
end

OutboxDispatchSmoke.new.call

# frozen_string_literal: true

# Standalone test process: no transactional fixtures or inline worker adapters.
ENV["RAILS_ENV"] = "test"
require_relative "../dummy/config/environment"
require "rack/mock"
require "nokogiri"
require "sidekiq/api"
require "securerandom"
require "fileutils"
require "timeout"

STDOUT.sync = true

abort "Worker E2E is test-only" unless Rails.env.test?
abort "Dedicated Redis DB required" unless ENV.fetch("REDIS_URL", "").end_with?("/12")

class WorkerSmoke
  MAX_SECONDS = 75

  def initialize
    @host_root = Rails.root
    @log_dir = @host_root.join("tmp/worker-e2e")
    FileUtils.mkdir_p(@log_dir)
    @workers = []
    @token = SecureRandom.hex(5)
    ENV["REKORRA_DEMO_PASSWORD"] = "worker-e2e-ci-only"
    Sidekiq.redis { |redis| redis.flushdb }
    puts "Sidekiq #{Gem.loaded_specs.fetch('sidekiq').version}; connection_pool #{Gem.loaded_specs.fetch('connection_pool').version}"
    puts "Queue SQLite adapter busy-handler timeout configured=#{SolidQueue::Record.connection.pool.db_config.configuration_hash.fetch(:timeout)}ms"
  end

  def call
    acme = Organization.find_or_create_by!(slug: "acme") { |org| org.name = "Acme" }
    globex = Organization.find_or_create_by!(slug: "globex") { |org| org.name = "Globex" }
    own_customer = Customer.create!(organization: acme, name: "E2E Own #{@token}",
      email: "own-#{@token}@worker.test")
    other_customer = Customer.create!(organization: globex, name: "E2E Other #{@token}",
      email: "other-#{@token}@worker.test")

    solid_ticket = Ticket.create!(customer: own_customer, number: "E2E-SOLID-#{@token}",
      status: "pending", estimated_minutes: 100)
    sidekiq_ticket = Ticket.create!(customer: own_customer, number: "E2E-SIDEKIQ-#{@token}",
      status: "pending", estimated_minutes: 200)
    foreign_ticket = Ticket.create!(customer: other_customer, number: "E2E-FOREIGN-#{@token}",
      status: "pending", estimated_minutes: 300)

    check_solid_queue(solid_ticket, foreign_ticket)
    check_sidekiq(sidekiq_ticket, foreign_ticket)
    puts "PASS: real worker processes, persisted effects, failures, retry and tenant privacy"
  ensure
    stop_workers
  end

  private

  def check_solid_queue(ticket, foreign)
    successful = TicketSummaryJob.perform_later(ticket.id)
    link(ticket, successful.job_id, provider: "solid_queue", klass: "TicketSummaryJob")
    failing = TicketSummaryJob.perform_later(-9_000_000_001)
    link(ticket, failing.job_id, provider: "solid_queue", klass: "TicketSummaryJob")
    other = TicketSummaryJob.perform_later(foreign.id)
    link(foreign, other.job_id, provider: "solid_queue", klass: "TicketSummaryJob")

    check(ticket.reload.summary_generated_at.nil?, "Solid Queue executed without a worker")
    assert_status(ticket, successful.job_id, "Queued", sidekiq: false)
    check(!show(ticket, sidekiq: false).include?(other.job_id), "Solid Queue leaked tenant job")
    check(status_code(foreign, sidekiq: false) == 404, "Solid Queue leaked tenant record")

    pid = launch("solid", ["bundle", "exec", "rake", "solid_queue:start"])
    wait_for("Solid Queue success/failure", worker_pid: pid) do
      ticket.reload.summary_generated_at &&
        ::SolidQueue::Job.find_by(active_job_id: successful.job_id)&.finished_at &&
        ::SolidQueue::Job.find_by(active_job_id: other.job_id)&.finished_at &&
        ::SolidQueue::Job.find_by(active_job_id: failing.job_id)&.failed_execution
    end
    stop_worker(pid)
    assert_status(ticket, successful.job_id, "Finished", sidekiq: false)
    assert_status(ticket, failing.job_id, "Failed", sidekiq: false)
    check(!show(ticket, sidekiq: false).include?(other.job_id), "Solid Queue leaked finished foreign job")
    check(status_code(foreign, sidekiq: false) == 404, "Solid Queue foreign show succeeded")
    check(foreign.reload.summary_generated_at.present?, "Solid Queue foreign job never ran")
    check(!show(ticket, sidekiq: false).include?("Couldn't find Ticket"), "Solid Queue exposed exception")
    puts "PASS: Solid Queue real worker finished and failed jobs with scoped read"
  end

  def check_sidekiq(ticket, foreign)
    successful_jid = SidekiqTicketSummaryWorker.perform_async(ticket.id)
    link(ticket, successful_jid, provider: "sidekiq", klass: "SidekiqTicketSummaryWorker")
    failing_jid = SidekiqTicketSummaryWorker.perform_async(-9_000_000_002)
    link(ticket, failing_jid, provider: "sidekiq", klass: "SidekiqTicketSummaryWorker")
    other_jid = SidekiqTicketSummaryWorker.perform_async(foreign.id)
    link(foreign, other_jid, provider: "sidekiq", klass: "SidekiqTicketSummaryWorker")

    check(ticket.reload.summary_generated_at.nil?, "Sidekiq executed without a worker")
    assert_status(ticket, successful_jid, "Queued", sidekiq: true)
    check(!show(ticket, sidekiq: true).include?(other_jid), "Sidekiq leaked tenant JID")
    check(status_code(foreign, sidekiq: true) == 404, "Sidekiq foreign show succeeded")

    pid = launch("sidekiq", ["bundle", "exec", "sidekiq", "-r", "./config/environment.rb",
      "-q", "default", "-c", "1"])
    wait_for("Sidekiq success/retry", worker_pid: pid) do
      ticket.reload.summary_generated_at &&
        foreign.reload.summary_generated_at &&
        ::Sidekiq::RetrySet.new.any? { |job| job.jid == failing_jid }
    end
    stop_worker(pid)
    assert_status(ticket, failing_jid, "Retrying", sidekiq: true)
    # An absent successful JID is not proof of completion.
    assert_status(ticket, successful_jid, "Unavailable", sidekiq: true)
    check(!show(ticket, sidekiq: true).include?(other_jid), "Sidekiq leaked completed foreign JID")
    check(!show(ticket, sidekiq: true).include?("Couldn't find Ticket"), "Sidekiq exposed retry error")
    check(status_code(foreign, sidekiq: true) == 404, "Sidekiq foreign show succeeded")
    puts "PASS: Sidekiq real worker completed work, produced retry and kept unknown completion"
  end

  def link(ticket, job_id, provider:, klass:)
    check(job_id.present?, "Backend did not enqueue #{klass}")
    DemoJobLink.create!(ticket: ticket, active_job_id: job_id,
      job_class_name: klass, provider: provider, queue_name: "default")
  end

  def show(ticket, sidekiq:)
    request(ticket, sidekiq: sidekiq).body
  end

  def status_code(ticket, sidekiq:)
    request(ticket, sidekiq: sidekiq).status
  end

  def request(ticket, sidekiq:)
    resource = sidekiq ? "sidekiq_tickets" : "tickets"
    path = "/backoffice/resources/#{resource}/#{ticket.id}"
    auth = ActionController::HttpAuthentication::Basic.encode_credentials(
      "acme", ENV.fetch("REKORRA_DEMO_PASSWORD"))
    Rack::MockRequest.new(Rails.application).get(path,
      "HTTP_HOST" => "localhost", "HTTP_AUTHORIZATION" => auth)
  end

  def assert_status(ticket, jid, expected, sidekiq:)
    response = request(ticket, sidekiq: sidekiq)
    check(response.status == 200, "Ticket HTTP #{response.status}")
    document = Nokogiri::HTML(response.body)
    row = document.css("section.rk-jobs li.rk-jobs__item").find { |node| node.text.include?(jid) }
    check(row, "Missing linked #{jid} in Jobs section")
    actual = row.css(".rk-badge").text.strip
    check(actual == expected, "Expected #{jid} #{expected}, got #{actual.inspect}")
  end

  def launch(name, command)
    path = @log_dir.join("#{name}.log")
    pid = Process.spawn({ "RAILS_ENV" => "test" }, *command,
      chdir: @host_root.to_s, out: path.to_s, err: path.to_s, pgroup: true)
    @workers << pid
    puts "Started #{name} worker pid=#{pid}"
    pid
  end

  def wait_for(label, worker_pid:)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + MAX_SECONDS
    until yield
      exited, status = Process.waitpid2(worker_pid, Process::WNOHANG)
      raise "#{label}: worker exited early (#{status.inspect})" if exited
      raise "#{label} timed out after #{MAX_SECONDS}s" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.25
    end
    puts "Observed #{label} in real backend storage"
  rescue StandardError
    @log_dir.children.each do |path|
      lines = File.readlines(path)
      warn "--- #{path.basename}: first 20 lines ---"
      warn lines.first(20).join
      warn "--- #{path.basename}: first failure signatures ---"
      warn lines.grep(/SQLite3::BusyException|database is locked|StatementTimeout|ArgumentError|NoMethodError|FATAL|uncaught/i).first(15).join
      warn "--- #{path.basename}: last 60 lines ---"
      warn lines.last(60).join
    end
    raise
  end

  def check(value, message)
    raise message unless value
  end

  def stop_worker(pid)
    return unless @workers.delete(pid)
    Process.kill("TERM", -pid)
    Timeout.timeout(15) { Process.wait(pid) }
  rescue Errno::ESRCH, Errno::ECHILD
    nil
  rescue Timeout::Error
    Process.kill("KILL", -pid) rescue nil
    Process.wait(pid) rescue nil
  end

  def stop_workers
    @workers.dup.each { |pid| stop_worker(pid) }
  end
end

WorkerSmoke.new.call

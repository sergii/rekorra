# frozen_string_literal: true

# Standalone, PostgreSQL primary + PostgreSQL Solid Queue, two real OS workers.
ENV["RAILS_ENV"] = "test"
require_relative "../dummy/config/environment"
require "fileutils"
require "securerandom"
STDOUT.sync = true
abort "PostgreSQL primary required" unless ActiveRecord::Base.connection.adapter_name == "PostgreSQL"
abort "PostgreSQL queue required" unless SolidQueue::Record.connection.adapter_name == "PostgreSQL"
abort "Independent databases required" if SolidQueue::Record.connection.select_value("SELECT current_database()") ==
  ActiveRecord::Base.connection.select_value("SELECT current_database()")
abort "Two worker processes required" unless ENV.fetch("REKORRA_WORKER_PROCESSES", "1") == "2"

class WorkerResilienceSmoke
  TIMEOUT = 65
  def initialize
    @root = Rails.root
    @logs = @root.join("tmp/worker-resilience-logs")
    FileUtils.mkdir_p(@logs)
    @children = []
    @token = SecureRandom.hex(6)
  end

  def call
    begin
      start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      first, first_ids = enqueue("concurrent", 36)
      check(first.all? { |p| p.reload.started_at.nil? }, "Job ran without a worker")
      supervisor = launch("concurrent")
      wait_for("two real registered worker processes", supervisor) do
        SolidQueue::Process.where(kind: "Worker").count >= 2
      end
      wait_for("36 completed jobs", supervisor) { completed?(first, first_ids) }
      verify(first, first_ids)
      original_pids = first.map { |p| p.reload.started_pid }.uniq
      check(original_pids.size >= 2, "Only one worker executed jobs: #{original_pids.inspect}")
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
      puts "PASS: 36 persisted jobs executed on #{original_pids.size} worker PIDs, #{(36.0 / elapsed).round(2)} jobs/s (CI observation)"

      # All claimed work is complete BEFORE SIGKILL: pending-backlog restart,
      # NOT recovery of an in-flight claim.
      kill_group(supervisor, "KILL")
      puts "SIGKILL: entire supervisor worker process group #{supervisor}"
      pending, pending_ids = enqueue("pending", 12)
      sleep 0.65
      check(pending.all? { |p| p.reload.started_at.nil? }, "Backlog ran while worker was dead")
      replacement = launch("replacement")
      wait_for("12 pending jobs resumed", replacement) { completed?(pending, pending_ids) }
      verify(pending, pending_ids)
      replacement_pids = pending.map { |p| p.reload.started_pid }.uniq
      check((replacement_pids & original_pids).empty?, "Killed workers performed replacement work")
      puts "PASS: 12 queued jobs completed after restart by PIDs #{replacement_pids.inspect}"

      all_ids = first_ids + pending_ids
      jobs = SolidQueue::Job.where(active_job_id: all_ids)
      check(jobs.count == 48 && jobs.where.not(finished_at: nil).count == 48,
        "48 durable finished backend jobs required")
      check(SolidQueue::ReadyExecution.where(job_id: jobs.select(:id)).none?,
        "Finished job remains ready")
      check(SolidQueue::ClaimedExecution.where(job_id: jobs.select(:id)).none?,
        "Finished job remains claimed")
      puts "PASS: 48/48 finished, zero stuck ready or claimed jobs"
    ensure
      @children.dup.each { |pid| kill_group(pid, "TERM") }
    end
  end

  private

  def enqueue(label, count)
    probes = Array.new(count) { |i|
      WorkerResilienceProbe.create!(token: "#{@token}-#{label}-#{i}")
    }
    ids = probes.map { |p| WorkerResilienceJob.perform_later(p.id).job_id }
    check(ids.all?(&:present?), "No backend job ID")
    [probes, ids]
  end

  def completed?(probes, ids)
    WorkerResilienceProbe.where(id: probes.map(&:id)).where.not(finished_at: nil).count == probes.size &&
      SolidQueue::Job.where(active_job_id: ids).where.not(finished_at: nil).count == ids.size
  end

  def verify(probes, ids)
    check(WorkerResilienceProbe.where(id: probes.map(&:id), execution_count: 1).count == probes.size,
      "Missing or observed duplicate execution")
    check(SolidQueue::Job.where(active_job_id: ids).count == ids.size, "Missing queue job record")
    check(SolidQueue::FailedExecution.where(
      job_id: SolidQueue::Job.where(active_job_id: ids).select(:id)).none?,
      "Failed execution recorded")
  end

  def launch(name)
    file = @logs.join("#{name}.log")
    pid = Process.spawn({ "RAILS_ENV" => "test" }, "bundle", "exec", "rake",
      "solid_queue:start", chdir: @root.to_s, out: file.to_s,
      err: file.to_s, pgroup: true)
    @children << pid
    puts "Started #{name} supervisor #{pid}"
    pid
  end

  def kill_group(pid, signal)
    return unless @children.delete(pid)
    Process.kill(signal, -pid)
    Process.waitpid(pid)
  rescue Errno::ECHILD, Errno::ESRCH
    nil
  end

  def wait_for(label, pid)
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + TIMEOUT
    until yield
      exited, status = Process.waitpid2(pid, Process::WNOHANG)
      raise "#{label}: supervisor exited early (#{status.inspect})" if exited
      raise "#{label}: deadline #{TIMEOUT}s exceeded" if Process.clock_gettime(Process::CLOCK_MONOTONIC) >= deadline
      sleep 0.2
    end
    puts "Observed #{label}"
  rescue StandardError
    @logs.children.each do |file|
      lines = File.readlines(file)
      warn "--- #{file.basename}: first errors ---"
      warn lines.grep(/ERROR|FATAL|PG::|ActiveRecord::|Exception|deadlock/i).first(30).join
      warn "--- #{file.basename}: tail ---"
      warn lines.last(70).join
    end
    raise
  end

  def check(value, message)
    raise message unless value
  end
end

WorkerResilienceSmoke.new.call

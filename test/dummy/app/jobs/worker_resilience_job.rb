# frozen_string_literal: true

# Host-only observable work, not an exactly-once delivery promise.
class WorkerResilienceJob < ApplicationJob
  queue_as :default
  def perform(probe_id)
    probe = WorkerResilienceProbe.find(probe_id)
    raise "Duplicate completed job #{probe_id}" if probe.finished_at?
    probe.update!(started_pid: Process.pid, started_at: Time.current)
    sleep 0.15
    probe.update!(finished_at: Time.current, execution_count: probe.execution_count + 1)
  end
end

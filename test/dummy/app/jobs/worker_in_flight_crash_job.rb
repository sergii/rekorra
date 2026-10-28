# frozen_string_literal: true

# Deliberately non-idempotent *test fixture*: count starts durably before sleep.
# A crashed first execution leaves the visible side effect behind.
# A subsequent manual retry completes but records two attempts.
class WorkerInFlightCrashJob < ApplicationJob
  queue_as :default

  def perform(probe_id)
    probe = WorkerResilienceProbe.find(probe_id)
    raise "Already completed #{probe_id}" if probe.finished_at?

    attempt = probe.execution_count + 1
    probe.update!(execution_count: attempt, started_pid: Process.pid, started_at: Time.current)

    sleep 30 if attempt == 1

    probe.update!(finished_at: Time.current)
  end
end

# frozen_string_literal: true

# First attempt commits local effect before being killed in the E2E.
# Retry and independently enqueued duplicates share the same operation key.
class WorkerIdempotentRecoveryJob < ApplicationJob
  queue_as :default

  def perform(probe_id, order_id, idempotency_key, pause_first = true)
    probe = WorkerResilienceProbe.find(probe_id)
    attempt = probe.execution_count + 1
    probe.update!(execution_count: attempt, started_pid: Process.pid, started_at: Time.current)
    WorkerRecoveryEffect.apply_once!(order_id: order_id, key: idempotency_key)
    sleep 30 if pause_first && attempt == 1
    probe.update!(finished_at: Time.current)
  end
end

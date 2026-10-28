# frozen_string_literal: true

# Globally aggregated host metrics: never render to tenant pages as-is.
class WorkerRecoveryHealth
  Snapshot = Struct.new(:failed_count, :aged_claim_count, :registered_workers,
    :oldest_failure_age_seconds, keyword_init: true)

  def self.snapshot(now: Time.current, aged_after: 15.minutes)
    oldest = SolidQueue::FailedExecution.minimum(:created_at)
    Snapshot.new(
      failed_count: SolidQueue::FailedExecution.count,
      aged_claim_count: SolidQueue::ClaimedExecution.where(created_at: ..(now - aged_after)).count,
      registered_workers: SolidQueue::Process.where(kind: "Worker").count,
      oldest_failure_age_seconds: oldest ? [(now - oldest).to_i, 0].max : nil
    )
  end
end

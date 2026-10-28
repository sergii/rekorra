# frozen_string_literal: true

# Aggregate-only host operations signal. Never expose globally to tenant pages.
class WorkerOutboxHealth
  Snapshot = Struct.new(:pending_count, :unknown_count, :delivered_count,
    :oldest_unknown_age_seconds, keyword_init: true)

  def self.snapshot(now: Time.current)
    oldest = WorkerOutboxEvent.where(status: "unknown").minimum(:created_at)
    Snapshot.new(
      pending_count: WorkerOutboxEvent.where(status: "pending").count,
      unknown_count: WorkerOutboxEvent.where(status: "unknown").count,
      delivered_count: WorkerOutboxEvent.where(status: "delivered").count,
      oldest_unknown_age_seconds: oldest ? [(now - oldest).to_i, 0].max : nil
    )
  end
end

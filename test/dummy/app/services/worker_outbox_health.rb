# frozen_string_literal: true

# Aggregate-only host operations signal. Never expose globally to tenant pages.
class WorkerOutboxHealth
  Snapshot = Struct.new(:pending_count, :unknown_count, :delivered_count,
    :needs_review_count, :active_lease_count, :expired_lease_count,
    :oldest_pending_age_seconds, :oldest_unknown_age_seconds, keyword_init: true)

  def self.snapshot(now: Time.current)
    oldest_unknown = WorkerOutboxEvent.where(status: "unknown").minimum(:created_at)
    oldest_pending = WorkerOutboxEvent.where(status: "pending").minimum(:created_at)
    Snapshot.new(
      pending_count: WorkerOutboxEvent.where(status: "pending").count,
      unknown_count: WorkerOutboxEvent.where(status: "unknown").count,
      delivered_count: WorkerOutboxEvent.where(status: "delivered").count,
      needs_review_count: WorkerOutboxEvent.where(status: "needs_review").count,
      active_lease_count: WorkerOutboxEvent.where("lease_expires_at > ?", now).count,
      expired_lease_count: WorkerOutboxEvent.where("lease_expires_at <= ?", now).count,
      oldest_pending_age_seconds: oldest_pending ? [(now - oldest_pending).to_i, 0].max : nil,
      oldest_unknown_age_seconds: oldest_unknown ? [(now - oldest_unknown).to_i, 0].max : nil
    )
  end
end

# frozen_string_literal: true

# Host-owned audit trail for explicit re-opening of a dead-letter event.
class WorkerOutboxReviewDecision < ApplicationRecord
  belongs_to :worker_outbox_event
  belongs_to :organization
  validates :reason, :actor_key, presence: true
end

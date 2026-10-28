# frozen_string_literal: true

# Host-only durable delivery intent; never stores arbitrary HTTP payloads.
class WorkerOutboxEvent < ApplicationRecord
  belongs_to :organization
  belongs_to :order

  validates :operation_key, presence: true, length: { maximum: 100 }
  validates :status, inclusion: { in: %w[pending unknown delivered needs_review] }
  validates :attempts, :dispatch_attempts,
    numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  def delivered?
    status == "delivered"
  end
end

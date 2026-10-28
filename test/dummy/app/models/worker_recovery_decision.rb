# frozen_string_literal: true

# Durable approval request, not proof that backend dispatch succeeded.
class WorkerRecoveryDecision < ApplicationRecord
  belongs_to :order
  validates :active_job_id, :actor_key, :reason, :action, presence: true
  validates :active_job_id, uniqueness: true
end

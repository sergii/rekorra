# frozen_string_literal: true

module Crm
  class Onboarding < ApplicationRecord
    self.table_name = "crm_onboardings"
    belongs_to :organization
    enum :stage, { started: "started", dispatched: "dispatched", awaiting_confirmation: "awaiting_confirmation", confirmed: "confirmed" }
    enum :health, { healthy: "healthy", failed: "failed", overdue: "overdue", unknown: "unknown" }
    validates :reference, :company_name, :stage, :health, :assigned_to, :stage_entered_at, presence: true
    validates :reference, uniqueness: { scope: :organization_id }
  end
end

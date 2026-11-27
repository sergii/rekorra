# frozen_string_literal: true

module Crm
  class Lead < ApplicationRecord
    self.table_name = "crm_leads"
    belongs_to :organization
    enum :stage, { new_lead: "new_lead", contacted: "contacted", qualified: "qualified", won: "won", lost: "lost" }
    validates :reference, :company_name, :contact_email, :stage, :assigned_to, presence: true
    validates :reference, uniqueness: { scope: :organization_id }
  end
end

# frozen_string_literal: true

module Crm
  class LeadResource < Rekorra::Resource
    model "Crm::Lead"
    title "Leads"
    navigation group: ["CRM", "Sales"], position: 10

    index do
      field :reference
      field :company_name
      field :stage, as: :badge
      field :assigned_to
      field :follow_up_on
      search_by :reference, :company_name, :contact_email
      sort_by :reference, :company_name, :created_at
      filter :stage, type: :select, options: %w[new_lead contacted qualified won lost]
    end

    show do
      field :reference
      field :company_name
      field :contact_email
      field :stage, as: :badge
      field :assigned_to
      field :follow_up_on
    end
  end
end

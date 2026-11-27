# frozen_string_literal: true

module Crm
  class OnboardingResource < Rekorra::Resource
    model "Crm::Onboarding"
    title "Customer onboarding"
    navigation group: ["CRM", "Customer success"], position: 10

    index do
      field :reference
      field :company_name
      field :stage, as: :badge
      field :health, as: :badge
      field :assigned_to
      field :stage_entered_at, as: :datetime
      search_by :reference, :company_name
      sort_by :reference, :company_name, :stage_entered_at
      filter :stage, type: :select, options: %w[started dispatched awaiting_confirmation confirmed]
      filter :health, type: :select, options: %w[healthy failed overdue unknown]
    end

    show do
      field :reference
      field :company_name
      field :stage, as: :badge
      field :health, as: :badge
      field :assigned_to
      field :stage_entered_at, as: :datetime
      field :finding
    end
  end
end

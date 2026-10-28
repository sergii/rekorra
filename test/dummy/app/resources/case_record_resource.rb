# frozen_string_literal: true

class CaseRecordResource < Rekorra::Resource
  model "CaseRecord"

  index do
    field :title
    field :state, as: :badge
    sort_by :title, :created_at
    filter :state, type: :select, options: %w[open reviewing closed]
  end

  show do
    field :title
    field :state, as: :enum
  end

  form do
    field :title
    field :organization_id
    field :state, as: :enum
  end
end

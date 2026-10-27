# frozen_string_literal: true

class OrganizationResource < Rekorra::Resource
  model "Organization"
  search_by :name, :slug

  index do
    field :name
    field :slug
  end

  show do
    field :name
    field :slug
    association :customers
  end
end

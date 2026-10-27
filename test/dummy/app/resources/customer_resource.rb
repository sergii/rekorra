# frozen_string_literal: true

class CustomerResource < Rekorra::Resource
  model "Customer"
  search_by :name, :email

  index do
    field :name
    field :email
  end

  show do
    field :name
    field :email
    association :orders
  end
end

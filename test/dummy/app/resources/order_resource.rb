# frozen_string_literal: true

class OrderResource < Rekorra::Resource
  model "Order"
  search_by :number, :status

  index do
    field :number
    field :customer
    field :status, as: :badge
    field :total_cents, as: :money, label: "Total"
    field :created_at, as: :datetime
  end

  show do
    field :number
    field :customer
    field :status, as: :badge
    field :total_cents, as: :money, label: "Total"
    field :created_at, as: :datetime
    association :payments
  end

  form do
    field :number
    field :customer_id
    field :status
    field :total_cents, label: "Total in cents"
  end
end

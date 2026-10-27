# frozen_string_literal: true

class PaymentResource < Rekorra::Resource
  model "Payment"
  search_by :status

  index do
    field :id
    field :order
    field :status, as: :badge
    field :amount_cents, as: :money, label: "Amount"
  end

  show do
    field :id
    field :order
    field :status, as: :badge
    field :amount_cents, as: :money, label: "Amount"
  end

  form do
    field :order_id
    field :status
    field :amount_cents, label: "Amount in cents"
  end
end

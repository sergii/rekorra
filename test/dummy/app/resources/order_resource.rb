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

  # External link configuration is owned by the demo host application.
  # Query values are numeric IDs, not untrusted names or email addresses.
  external_link :logs, label: "See logs", provider: :sumo_logic,
    query: ->(order) {
      "_sourceCategory=rekorra/demo order_id=#{Integer(order.id)} tenant_id=#{Integer(order.customer.organization_id)}"
    }, start_time: "-24h", end_time: "now", authorize: :view_logs?

  external_link :issues, label: "Find related issues", provider: :url,
    base_url: "https://github.com", path: "/sergii/rekorra/issues",
    params: ->(order) { { q: "order_id:#{Integer(order.id)}" } },
    authorize: :view_issues?

  form do
    field :number
    field :customer_id
    field :status
    field :total_cents, label: "Total in cents"
  end
end

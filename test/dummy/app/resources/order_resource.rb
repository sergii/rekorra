# frozen_string_literal: true

class OrderResource < Rekorra::Resource
  model "Order"
  search_by :number, :status

  field_policy :total_cents, read: :view_total_cents?, write: :edit_total_cents?

  index do
    field :number
    field :customer
    field :status, as: :badge
    field :total_cents, as: :money, label: "Total"
    field :created_at, as: :datetime

    filter :status, type: :select, options: %w[pending paid fulfilled]
    filter :total_cents, type: :number_range
    filter :created_at, type: :date_range
    sort_by :number, :total_cents, :created_at

    pagination do
      strategy :offset
      per_page 25
      max_per_page 100
    end
  end

  show do
    field :number
    field :customer
    field :status, as: :badge
    field :total_cents, as: :money, label: "Total"
    field :created_at, as: :datetime
    association :payments
  end

  findings do
    rule :paid_but_pending
    authorize :view_findings?
    limit 10
  end

  jobs do
    source :solid_queue
    authorize :view_jobs?
    limit 10
  end

  activity do
    source :paper_trail
    fields :number, :status, :total_cents
    authorize :view_activity?
    limit 10
  end

  context do
    record :customer, resource: :customers, id: ->(order) { order.customer_id }
    record :organization, resource: :organizations,
      id: ->(order) { order.customer.organization_id }

    external :issue, provider: :jira, instance: "example.atlassian.net",
      kind: :issue, id: ->(order) { order.support_issue_id },
      display_key: ->(order) { order.support_issue_key },
      authorize: :view_issues?

    external :trace, provider: :datadog, instance: "us1",
      kind: :trace, id: ->(order) { order.trace_id },
      authorize: :view_logs?
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
    field :status, as: :enum
    field :total_cents, label: "Total in cents"
  end
end

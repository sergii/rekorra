# frozen_string_literal: true

class TicketResource < Rekorra::Resource
  model "Ticket"
  navigation group: ["CRM", "Support"]
  search_by :number, :status

  field_policy :estimated_minutes, read: :view_estimated_minutes?, write: :edit_estimated_minutes?

  index do
    field :number
    field :customer
    field :status, as: :badge
    field :estimated_minutes, label: "Estimated minutes"
    field :created_at, as: :datetime

    filter :status, type: :select, options: %w[pending completed resolved]
    filter :estimated_minutes, type: :number_range
    filter :created_at, type: :date_range
    sort_by :number, :estimated_minutes, :created_at

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
    field :estimated_minutes, label: "Estimated minutes"
    field :created_at, as: :datetime
    association :interactions
  end

  findings do
    rule :logged_but_pending
    authorize :view_findings?
    limit 10
  end

  jobs do
    source :solid_queue
    authorize :view_jobs?
    limit 10
  end

  access_audit do
    source :active_record
    authorize :view_access_audit?
    limit 10
  end

  activity do
    source :paper_trail
    fields :number, :status, :estimated_minutes
    authorize :view_activity?
    limit 10
  end

  context do
    record :customer, resource: :customers, id: ->(ticket) { ticket.customer_id }
    record :organization, resource: :organizations,
      id: ->(ticket) { ticket.customer.organization_id }

    external :issue, provider: :jira, instance: "example.atlassian.net",
      kind: :issue, id: ->(ticket) { ticket.support_issue_id },
      display_key: ->(ticket) { ticket.support_issue_key },
      authorize: :view_issues?

    external :trace, provider: :datadog, instance: "us1",
      kind: :trace, id: ->(ticket) { ticket.trace_id },
      authorize: :view_logs?
  end

  # External link configuration is owned by the demo host application.
  # Query values are numeric IDs, not untrusted names or email addresses.
  external_link :logs, label: "See logs", provider: :sumo_logic,
    query: ->(ticket) {
      "_sourceCategory=rekorra/demo ticket_id=#{Integer(ticket.id)} tenant_id=#{Integer(ticket.customer.organization_id)}"
    }, start_time: "-24h", end_time: "now", authorize: :view_logs?

  external_link :issues, label: "Find related issues", provider: :url,
    base_url: "https://github.com", path: "/sergii/rekorra/issues",
    params: ->(ticket) { { q: "ticket_id:#{Integer(ticket.id)}" } },
    authorize: :view_issues?

  form do
    field :number
    field :customer_id
    field :status
    field :estimated_minutes, label: "Estimated minutes"
  end
end

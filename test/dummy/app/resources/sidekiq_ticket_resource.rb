# frozen_string_literal: true

# Second view over the same scoped model, to demonstrate adapter interchange
# without making Sidekiq a mandatory source for the regular Ticket workspace.
class SidekiqTicketResource < Rekorra::Resource
  model "Ticket"
  search_by :number

  index do
    field :number
    field :status
    field :created_at, as: :datetime
  end

  show do
    field :number
    field :status
    field :customer
  end

  jobs do
    source :sidekiq
    authorize :view_jobs?
    limit 10
  end
end

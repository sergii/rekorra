# frozen_string_literal: true

# The ordinary Resource Index is designed for large model tables, not just
# specialized Findings, Activity or Jobs views.
class UserResource < Rekorra::Resource
  model "User"

  index do
    field :name
    field :email
    field :status, as: :badge
    field :role
    field :verified
    field :created_at, as: :datetime

    search_by :name, :email
    filter :status, type: :select, options: %w[active suspended invited]
    filter :role, type: :select, options: %w[member admin]
    filter :verified, type: :boolean
    filter :created_at, type: :date_range
    sort_by :name, :email, :created_at

    pagination do
      strategy :offset
      per_page 25
      max_per_page 100
    end
  end

  show do
    field :name
    field :email
    field :status
    field :role
    field :verified
    field :created_at, as: :datetime
  end
end

# frozen_string_literal: true

# Same ordinary Users table and tenant scope as UserResource, alternate
# pagination strategy. No new controller or model-specific view.
class CursorUserResource < Rekorra::Resource
  model "User"

  index do
    field :name
    field :email
    field :status, as: :badge
    field :role

    search_by :name, :email
    filter :status, type: :select, options: %w[active suspended invited]
    filter :role, type: :select, options: %w[member admin]
    sort_by :name, :email, :status

    pagination do
      strategy :keyset
      per_page 25
      max_per_page 100
    end
  end

  show do
    field :name
    field :email
    field :status
    field :role
  end
end

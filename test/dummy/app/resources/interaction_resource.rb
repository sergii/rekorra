# frozen_string_literal: true

class InteractionResource < Rekorra::Resource
  model "Interaction"
  navigation group: ["CRM", "Communications"]
  search_by :status

  index do
    field :id
    field :ticket
    field :status, renderer: ->(value, record:, field:) { "Channel: #{value.upcase}" }
    field :duration_minutes, label: "Duration minutes"
  end

  show do
    field :id
    field :ticket
    field :status, as: :badge
    field :duration_minutes, label: "Duration minutes"
  end

  form do
    field :ticket_id
    field :status
    field :duration_minutes, label: "Duration minutes"
  end
end

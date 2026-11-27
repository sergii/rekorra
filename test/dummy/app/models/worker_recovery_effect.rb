# frozen_string_literal: true

# Host-only idempotency ledger. The marker and the mutation use one DB
# transaction, protected by a record lock plus tenant-scoped unique key.
class WorkerRecoveryEffect < ApplicationRecord
  class KeyCollision < StandardError; end

  belongs_to :organization
  belongs_to :ticket
  validates :idempotency_key, presence: true, length: { maximum: 100 }
  validates :applied_at, presence: true

  def self.apply_once!(ticket_id:, key:)
    raise ArgumentError, "Invalid operation key" unless key.is_a?(String) &&
      key.match?(/\A[a-zA-Z0-9][a-zA-Z0-9:_-]{0,99}\z/)

    Ticket.transaction do
      ticket = Ticket.lock.find(ticket_id)
      tenant_id = ticket.customer.organization_id
      effect = create_or_find_by!(organization_id: tenant_id, idempotency_key: key) do |entry|
        entry.ticket_id = ticket.id
        entry.applied_at = Time.current
      end
      raise KeyCollision, "Key reused for a different record" unless effect.ticket_id == ticket.id

      if effect.previously_new_record?
        ticket.update!(estimated_minutes: ticket.estimated_minutes + 7)
        :applied
      else
        :already_applied
      end
    end
  end
end

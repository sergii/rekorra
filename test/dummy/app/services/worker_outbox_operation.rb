# frozen_string_literal: true

# One primary-DB commit: local idempotency marker + business mutation + outbox.
# Solid Queue is a DIFFERENT database; enqueueing a job is NOT part of this
# transaction. A periodic scanner or explicit dispatch schedule is required.
class WorkerOutboxOperation
  class KeyCollision < StandardError; end

  def self.apply_once!(ticket_id:, key:)
    Ticket.transaction do
      result = WorkerRecoveryEffect.apply_once!(ticket_id: ticket_id, key: key)
      ticket = Ticket.find(ticket_id)
      tenant_id = ticket.customer.organization_id
      event = WorkerOutboxEvent.create_or_find_by!(
        organization_id: tenant_id, operation_key: key
      ) { |entry| entry.ticket_id = ticket.id }
      raise KeyCollision, "Outbox key belongs to a different ticket" unless event.ticket_id == ticket.id

      [result, event]
    end
  end
end

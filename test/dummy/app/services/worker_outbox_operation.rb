# frozen_string_literal: true

# One primary-DB commit: local idempotency marker + business mutation + outbox.
# Solid Queue is a DIFFERENT database; enqueueing a job is NOT part of this
# transaction. A periodic scanner or explicit dispatch schedule is required.
class WorkerOutboxOperation
  class KeyCollision < StandardError; end

  def self.apply_once!(order_id:, key:)
    Order.transaction do
      result = WorkerRecoveryEffect.apply_once!(order_id: order_id, key: key)
      order = Order.find(order_id)
      tenant_id = order.customer.organization_id
      event = WorkerOutboxEvent.create_or_find_by!(
        organization_id: tenant_id, operation_key: key
      ) { |entry| entry.order_id = order.id }
      raise KeyCollision, "Outbox key belongs to a different order" unless event.order_id == order.id

      [result, event]
    end
  end
end

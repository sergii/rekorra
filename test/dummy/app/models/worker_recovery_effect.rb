# frozen_string_literal: true

# Host-only idempotency ledger. The marker and the mutation use one DB
# transaction, protected by a record lock plus tenant-scoped unique key.
class WorkerRecoveryEffect < ApplicationRecord
  class KeyCollision < StandardError; end

  belongs_to :organization
  belongs_to :order
  validates :idempotency_key, presence: true, length: { maximum: 100 }
  validates :applied_at, presence: true

  def self.apply_once!(order_id:, key:)
    raise ArgumentError, "Invalid operation key" unless key.is_a?(String) &&
      key.match?(/\A[a-zA-Z0-9][a-zA-Z0-9:_-]{0,99}\z/)

    Order.transaction do
      order = Order.lock.find(order_id)
      tenant_id = order.customer.organization_id
      effect = create_or_find_by!(organization_id: tenant_id, idempotency_key: key) do |entry|
        entry.order_id = order.id
        entry.applied_at = Time.current
      end
      raise KeyCollision, "Key reused for a different record" unless effect.order_id == order.id

      if effect.previously_new_record?
        order.update!(total_cents: order.total_cents + 7)
        :applied
      else
        :already_applied
      end
    end
  end
end

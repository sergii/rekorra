# frozen_string_literal: true

# Demo-only, idempotent action. Enqueue does not perform the work until a worker
# runs; the record's receipt_generated_at is changed only on successful perform.
class OrderReceiptJob < ApplicationJob
  queue_as :default

  def perform(order_id)
    order = Order.find(order_id)
    order.update!(receipt_generated_at: Time.current) if order.receipt_generated_at.nil?
  end
end

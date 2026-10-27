# frozen_string_literal: true

# Optional demo worker: enqueue into a real Redis-backed Sidekiq instance.
class SidekiqOrderReceiptWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 2

  def perform(order_id)
    order = Order.find(order_id)
    order.update!(receipt_generated_at: Time.current) unless order.receipt_generated_at
  end
end

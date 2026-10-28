# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

# Host-only transport. The receiver MUST deduplicate by the stable key.
# Do not hold a DB row lock during an external request.
class WorkerOutboxDelivery
  class Uncertain < StandardError; end
  class InvalidReceipt < StandardError; end

  def self.deliver!(event_id:, endpoint:)
    event = WorkerOutboxEvent.find(event_id)
    event.with_lock do
      return :already_delivered if event.delivered?
      event.update!(attempts: event.attempts + 1, last_attempt_at: Time.current)
    end

    uri = URI.join(endpoint, "/deliver")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Idempotency-Key"] = key_for(event)
    request.body = JSON.generate(order_id: event.order_id, organization_id: event.organization_id)
    response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 2, read_timeout: 2) do |http|
      http.request(request)
    end
    raise Uncertain, "Provider did not acknowledge delivery" unless response.code == "200"
    receipt = JSON.parse(response.body)
    verify_receipt!(receipt, event)
    event.with_lock do
      event.update!(status: "delivered", provider_receipt: receipt.fetch("receipt"),
        delivered_at: Time.current) unless event.delivered?
    end
    :delivered
  rescue StandardError => error
    # A missing response is UNKNOWN, not proof the provider did nothing.
    # Never persist a raw remote response/exception with possible secrets.
    if event&.persisted?
      event.with_lock { event.update!(status: "unknown") unless event.delivered? }
    end
    raise Uncertain, "Delivery acknowledgment unavailable (#{error.class})"
  end

  def self.reconcile!(event_id:, endpoint:)
    event = WorkerOutboxEvent.find(event_id)
    return :already_delivered if event.delivered?

    uri = URI.join(endpoint, "/receipt?key=#{URI.encode_www_form_component(key_for(event))}")
    response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 2, read_timeout: 2) do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    return :not_found if response.code == "404"
    raise Uncertain, "Provider reconciliation unavailable" unless response.code == "200"
    receipt = JSON.parse(response.body)
    verify_receipt!(receipt, event)
    event.with_lock do
      event.update!(status: "delivered", provider_receipt: receipt.fetch("receipt"),
        delivered_at: Time.current) unless event.delivered?
    end
    :reconciled
  end

  def self.key_for(event)
    "#{event.organization_id}:#{event.operation_key}"
  end

  def self.verify_receipt!(receipt, event)
    unless receipt.is_a?(Hash) && receipt["key"] == key_for(event) &&
        receipt["receipt"].is_a?(String) && receipt["receipt"].match?(/\Aprovider-[a-f0-9]{12}\z/)
      raise InvalidReceipt, "Provider receipt did not match stable operation identity"
    end
  end
  private_class_method :key_for, :verify_receipt!
end

# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

# Host-only transport. The receiver MUST deduplicate by the stable key.
# No primary DB row lock is held across a network request. Optional lease_token
# fences scanner-owned writes after a worker loses its lease.
class WorkerOutboxDelivery
  class Uncertain < StandardError; end
  class InvalidReceipt < StandardError; end

  def self.deliver!(event_id:, endpoint:, lease_token: nil)
    event = WorkerOutboxEvent.find(event_id)
    event.with_lock do
      return :lease_lost if lost_lease?(event, lease_token)
      return :already_delivered if event.delivered?
      event.update!(attempts: event.attempts + 1, last_attempt_at: Time.current)
    end

    uri = URI.join(endpoint, "/deliver")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request["Idempotency-Key"] = key_for(event)
    request.body = JSON.generate(order_id: event.order_id, organization_id: event.organization_id)
    response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 2, read_timeout: 2,
      use_ssl: uri.scheme == "https") do |http|
      http.request(request)
    end
    raise Uncertain, "Provider did not acknowledge delivery" unless response.code == "200"
    receipt = JSON.parse(response.body)
    verify_receipt!(receipt, event)
    event.with_lock do
      return :lease_lost if lost_lease?(event, lease_token)
      event.update!(status: "delivered", provider_receipt: receipt.fetch("receipt"),
        delivered_at: Time.current) unless event.delivered?
    end
    :delivered
  rescue StandardError => error
    # A missing ACK is UNKNOWN, not proof of no effect. Do not let a late
    # process override a newer lease owner (or delivered status).
    if event&.persisted?
      event.with_lock do
        event.update!(status: "unknown") unless event.delivered? || lost_lease?(event, lease_token)
      end
    end
    raise Uncertain, "Delivery acknowledgment unavailable (#{error.class})"
  end

  def self.reconcile!(event_id:, endpoint:, lease_token: nil)
    event = WorkerOutboxEvent.find(event_id)
    return :lease_lost if lost_lease?(event, lease_token)
    return :already_delivered if event.delivered?

    uri = URI.join(endpoint, "/receipt?key=#{URI.encode_www_form_component(key_for(event))}")
    response = Net::HTTP.start(uri.hostname, uri.port, open_timeout: 2, read_timeout: 2,
      use_ssl: uri.scheme == "https") do |http|
      http.request(Net::HTTP::Get.new(uri))
    end
    return :not_found if response.code == "404"
    raise Uncertain, "Provider reconciliation unavailable" unless response.code == "200"
    receipt = JSON.parse(response.body)
    verify_receipt!(receipt, event)
    event.with_lock do
      return :lease_lost if lost_lease?(event, lease_token)
      event.update!(status: "delivered", provider_receipt: receipt.fetch("receipt"),
        delivered_at: Time.current) unless event.delivered?
    end
    :reconciled
  rescue StandardError => error
    raise Uncertain, "Reconciliation receipt unavailable (#{error.class})"
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

  def self.lost_lease?(event, token)
    token && event.lease_token != token
  end
  private_class_method :key_for, :verify_receipt!, :lost_lease?
end

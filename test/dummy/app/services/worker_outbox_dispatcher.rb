# frozen_string_literal: true

require "securerandom"
require "uri"

# Host-owned durable scanner. The queue is a SEPARATE database: never rely
# on queue enqueue being in the business transaction. An OS cron/systemd/K8s
# runner must invoke this periodically; this is NOT a built-in Rekorra daemon.
#
# Atomic conditional UPDATE provides a single owner among concurrent
# dispatchers. Expired leases are reclaimable after SIGKILL. An old worker
# cannot finalize an expired lease owned by another worker.
class WorkerOutboxDispatcher
  MAX_ATTEMPTS = 3
  LEASE_SECONDS = 15
  BACKOFF_SECONDS = [1, 2, 4].freeze

  class UnsafeEndpoint < StandardError; end
  Claim = Struct.new(:event_id, :token, keyword_init: true)

  def initialize(endpoint:, allowed_hosts:, allow_test_http: false)
    uri = URI.parse(endpoint)
    permitted = allowed_hosts.map(&:downcase)
    local = Rails.env.test? && allow_test_http &&
      uri.scheme == "http" && uri.host == "127.0.0.1"
    safe = uri.scheme == "https" && uri.host && permitted.include?(uri.host.downcase)
    unless (local || safe) && !uri.userinfo && !uri.query && !uri.fragment &&
        (uri.path.empty? || uri.path == "/")
      raise UnsafeEndpoint, "Endpoint must use HTTPS and an explicit trusted host"
    end
    @endpoint = "#{uri.scheme}://#{uri.host}:#{uri.port}"
  rescue URI::InvalidURIError, NoMethodError
    raise UnsafeEndpoint, "Invalid provider endpoint"
  end

  def claim_one!(now: Time.current, lease_seconds: LEASE_SECONDS)
    raise ArgumentError, "Lease must be positive" unless lease_seconds.positive?

    eligible(now: now).limit(50).pluck(:id).each do |id|
      token = SecureRandom.hex(16)
      count = eligible(now: now).where(id: id).update_all([
        "lease_token = ?, lease_expires_at = ?, last_dispatcher_pid = ?, " \
        "dispatch_attempts = dispatch_attempts + 1, updated_at = ?",
        token, now + lease_seconds, Process.pid, now
      ])
      return Claim.new(event_id: id, token: token) if count == 1
    end
    nil
  end

  def dispatch_once!(now: Time.current)
    mark_exhausted!(now: now)
    claim = claim_one!(now: now)
    return :idle unless claim

    event = WorkerOutboxEvent.find(claim.event_id)
    begin
      if event.status == "unknown"
        outcome = WorkerOutboxDelivery.reconcile!(
          event_id: event.id, endpoint: @endpoint, lease_token: claim.token
        )
        if outcome == :not_found
          outcome = WorkerOutboxDelivery.deliver!(
            event_id: event.id, endpoint: @endpoint, lease_token: claim.token
          )
        end
      else
        outcome = WorkerOutboxDelivery.deliver!(
          event_id: event.id, endpoint: @endpoint, lease_token: claim.token
        )
      end
      finish!(claim, now: now)
      outcome
    rescue WorkerOutboxDelivery::Uncertain
      fail!(claim, now: now, reason: "uncertain")
      :uncertain
    end
  end

  def drain!(max: 100)
    Array.new(max) { dispatch_once! }.take_while { |result| result != :idle }
  end

  private

  def eligible(now:)
    WorkerOutboxEvent.where(status: %w[pending unknown])
      .where("dispatch_attempts < ?", MAX_ATTEMPTS)
      .where("next_attempt_at IS NULL OR next_attempt_at <= ?", now)
      .where("lease_expires_at IS NULL OR lease_expires_at <= ?", now)
      .order(:id)
  end

  def mark_exhausted!(now:)
    WorkerOutboxEvent.where(status: %w[pending unknown])
      .where("dispatch_attempts >= ?", MAX_ATTEMPTS)
      .where("lease_expires_at IS NULL OR lease_expires_at <= ?", now)
      .update_all(status: "needs_review", lease_token: nil,
        lease_expires_at: nil, last_failure_kind: "attempts_exhausted",
        next_attempt_at: nil, updated_at: now)
  end

  def finish!(claim, now:)
    WorkerOutboxEvent.where(id: claim.event_id, lease_token: claim.token)
      .update_all(lease_token: nil, lease_expires_at: nil,
        next_attempt_at: nil, last_failure_kind: nil, updated_at: now)
  end

  def fail!(claim, now:, reason:)
    event = WorkerOutboxEvent.find(claim.event_id)
    exhausted = event.dispatch_attempts >= MAX_ATTEMPTS
    delay = BACKOFF_SECONDS.fetch([event.dispatch_attempts - 1, BACKOFF_SECONDS.size - 1].min)
    WorkerOutboxEvent.where(id: claim.event_id, lease_token: claim.token)
      .update_all(status: exhausted ? "needs_review" : "unknown",
        last_failure_kind: exhausted ? "attempts_exhausted" : reason,
        next_attempt_at: exhausted ? nil : now + delay,
        lease_token: nil, lease_expires_at: nil, updated_at: now)
  end
end

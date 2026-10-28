# frozen_string_literal: true

# Trusted host-side operator action; intentionally NOT a Rekorra controller.
# Durable approval is recorded before clearing a terminal outbox state.
class WorkerOutboxReview
  class Rejected < StandardError; end

  def self.reopen!(event:, actor:, reason:)
    raise Rejected, "Operator required" unless actor.is_a?(Organization)
    raise Rejected, "Cross-tenant outbox intent" unless event.organization_id == actor.id
    raise Rejected, "Recovery policy denied" unless
      Rekorra.configuration.authorize_with.call(actor, event.order, :retry_job?) == true
    raise Rejected, "Reason required" unless
      reason.is_a?(String) && reason.strip.length.between?(12, 500)

    event.with_lock do
      raise Rejected, "Only operator-review events can be reopened" unless event.status == "needs_review"
      WorkerOutboxReviewDecision.create!(
        worker_outbox_event: event, organization: actor,
        actor_key: "organization:#{actor.id}", reason: reason.strip)
      event.update!(status: "unknown", dispatch_attempts: 0,
        next_attempt_at: nil, lease_token: nil, lease_expires_at: nil,
        last_failure_kind: nil)
    end
    :reopened
  end
end

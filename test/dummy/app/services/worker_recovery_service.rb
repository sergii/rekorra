# frozen_string_literal: true

# Host-only trusted operation, NOT a Rekorra controller or public retry API.
class WorkerRecoveryService
  class Rejected < StandardError; end

  def self.retry_failed!(actor:, order:, job_id:, reason:)
    raise Rejected, "Invalid operator" unless actor.is_a?(Organization)
    raise Rejected, "Cross-tenant record" unless order.customer.organization_id == actor.id
    raise Rejected, "Retry policy denied" unless
      Rekorra.configuration.authorize_with.call(actor, order, :retry_job?)
    raise Rejected, "Approval reason required" unless
      reason.is_a?(String) && reason.strip.length.between?(12, 500)
    raise Rejected, "Invalid job ID" unless job_id.is_a?(String) &&
      job_id.match?(/\A[a-zA-Z0-9_-]{10,100}\z/)

    link = order.demo_job_links.find_by(active_job_id: job_id,
      provider: "solid_queue", job_class_name: "WorkerIdempotentRecoveryJob")
    raise Rejected, "Job is unlinked or not approved for replay" unless link
    backend = SolidQueue::Job.find_by(active_job_id: job_id,
      class_name: "WorkerIdempotentRecoveryJob")
    raise Rejected, "Backend job not found" unless backend
    failure = SolidQueue::FailedExecution.find_by(job_id: backend.id)
    raise Rejected, "Job is not failed" unless failure

    # Persist the operator decision BEFORE requesting queue mutation. If retry
    # raises, the row records an attempted action; reconcile backend state.
    decision = WorkerRecoveryDecision.create!(
      order: order, active_job_id: job_id,
      actor_key: "organization:#{actor.id}", action: "retry_requested",
      reason: reason.strip)
    failure.retry
    decision
  rescue ActiveRecord::RecordNotUnique, ActiveRecord::RecordInvalid
    raise Rejected, "Recovery already requested or invalid"
  end
end

# frozen_string_literal: true

# Host-owned domain rule. The Ticket has already been scoped and authorized by
# Rekorra. Its interactions are reached only through the Ticket association.
class LoggedButPending
  def evaluate(record:)
    return nil unless record.is_a?(Ticket) && record.status == "pending"
    return nil unless record.estimated_minutes.positive?

    logged_minutes = record.interactions.where(status: "logged").sum(:duration_minutes)
    return nil if logged_minutes < record.estimated_minutes

    Rekorra::Findings::Finding.new(
      code: "logged_but_pending", severity: "warning",
      title: "Interaction logged, ticket still pending",
      description: "Logged interactions meet the estimated duration, but the ticket has not advanced beyond pending.",
      evidence: [
        Rekorra::Findings::Evidence.new(label: "Ticket status", value: record.status),
        Rekorra::Findings::Evidence.new(label: "Ticket estimate (minutes)", value: record.estimated_minutes),
        Rekorra::Findings::Evidence.new(label: "Logged (minutes)", value: logged_minutes)
      ]
    )
  end
end

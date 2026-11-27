# frozen_string_literal: true

# Demo-only, idempotent action. Enqueue does not perform the work until a worker
# runs; the record's summary_generated_at is changed only on successful perform.
class TicketSummaryJob < ApplicationJob
  queue_as :default

  def perform(ticket_id)
    ticket = Ticket.find(ticket_id)
    ticket.update!(summary_generated_at: Time.current) if ticket.summary_generated_at.nil?
  end
end

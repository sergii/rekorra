# frozen_string_literal: true

# Optional demo worker: enqueue into a real Redis-backed Sidekiq instance.
class SidekiqTicketSummaryWorker
  include Sidekiq::Job

  sidekiq_options queue: :default, retry: 2

  def perform(ticket_id)
    ticket = Ticket.find(ticket_id)
    ticket.update!(summary_generated_at: Time.current) unless ticket.summary_generated_at
  end
end

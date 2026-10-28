# frozen_string_literal: true

# On any crash after the provider commit, the event remains pending/unknown.
# Retry uses the SAME stable idempotency key, never a new random key.
class WorkerOutboxDeliveryJob < ApplicationJob
  queue_as :default

  def perform(event_id, port_file)
    port = Integer(File.read(port_file))
    raise "Invalid local provider port" unless port.between?(1, 65_535)
    WorkerOutboxDelivery.deliver!(event_id: event_id, endpoint: "http://127.0.0.1:#{port}")
  end
end

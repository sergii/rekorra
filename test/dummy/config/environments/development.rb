# frozen_string_literal: true

Rails.application.configure do
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }
  config.eager_load = false
  config.consider_all_requests_local = true
end

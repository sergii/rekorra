# frozen_string_literal: true

Rails.application.configure do
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = { database: { writing: :queue } }
  # Preserve backend completion metadata for the process-level acceptance gate.
  config.solid_queue.preserve_finished_jobs = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.action_dispatch.show_exceptions = :none
  config.active_support.deprecation = :stderr
end

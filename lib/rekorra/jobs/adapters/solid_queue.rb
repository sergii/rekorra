# frozen_string_literal: true

module Rekorra
  module Jobs
    module Adapters
      # The host provides its own record-owned correlation relation, e.g.
      # order.demo_job_links. Never parse Solid Queue's serialized arguments
      # to discover a business record or tenant.
      class SolidQueue
        def initialize(links:)
          raise ConfigurationError, "Jobs links callback required" unless links.respond_to?(:call)
          @links = links
        end

        def jobs(record:, limit:)
          raise ConfigurationError, "Solid Queue is not installed" unless defined?(::SolidQueue::Job)
          relation = @links.call(record)
          unless relation.is_a?(ActiveRecord::Relation)
            raise ConfigurationError, "Job links must be a record-scoped ActiveRecord::Relation"
          end

          # Host callback must return an association already scoped to the record.
          # It is intentionally not inferred from serialized job arguments.
          links = relation.order(id: :desc).limit(limit).to_a
          active_ids = links.map(&:active_job_id).compact.uniq
          backend_jobs = ::SolidQueue::Job
            .where(active_job_id: active_ids)
            .includes(:failed_execution, :claimed_execution, :ready_execution,
              :scheduled_execution, :blocked_execution)
            .index_by(&:active_job_id)

          links.map do |link|
            job = backend_jobs[link.active_job_id]
            Item.new(
              id: link.active_job_id.to_s,
              name: job&.class_name || link.job_class_name,
              queue: job&.queue_name || "unknown",
              status: status_for(job),
              created_at: job&.created_at || link.created_at,
              scheduled_at: job&.scheduled_at,
              finished_at: job&.finished_at
            )
          end
        end

        private

        def status_for(job)
          return "unavailable" unless job
          return "failed" if job.failed_execution
          return "finished" if job.finished_at
          return "running" if job.claimed_execution
          return "blocked" if job.blocked_execution
          return "scheduled" if job.scheduled_execution
          return "queued" if job.ready_execution

          "unknown"
        end
      end
    end
  end
end

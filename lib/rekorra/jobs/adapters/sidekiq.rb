# frozen_string_literal: true

module Rekorra
  module Jobs
    module Adapters
      # Read-only, bounded best-effort Sidekiq snapshot of *explicitly linked*
      # jobs. Does not use job arguments to associate records, and does not
      # report "finished" when a job is absent from Redis.
      #
      # Sidekiq's Data API is eventually consistent and scan-based; this
      # adapter is for small inspection views, not bulk production monitoring.
      class Sidekiq
        DEFAULT_SCAN_LIMIT = 100
        MAX_SCAN_LIMIT = 500

        def initialize(links:, scan_limit: DEFAULT_SCAN_LIMIT)
          raise ConfigurationError, "Sidekiq links callback required" unless links.respond_to?(:call)
          @scan_limit = Integer(scan_limit)
          unless @scan_limit.between?(1, MAX_SCAN_LIMIT)
            raise ConfigurationError, "Sidekiq scan limit must be between 1 and #{MAX_SCAN_LIMIT}"
          end
          @links = links
        end

        def jobs(record:, limit:)
          unless defined?(::Sidekiq::Queue) && defined?(::Sidekiq::ScheduledSet) &&
              defined?(::Sidekiq::RetrySet) && defined?(::Sidekiq::DeadSet)
            raise ConfigurationError, "Sidekiq API is not installed"
          end

          relation = @links.call(record)
          unless relation.is_a?(ActiveRecord::Relation)
            raise ConfigurationError, "Sidekiq links must be a record-scoped ActiveRecord::Relation"
          end
          links = relation.reorder(id: :desc).limit(limit).to_a
          return [] if links.empty?

          wanted = links.map(&:active_job_id).to_h { |jid| [jid.to_s, true] }
          matches = {}
          links.map(&:queue_name).uniq.each do |queue|
            next unless safe_queue_name?(queue)

            scan(::Sidekiq::Queue.new(queue), wanted, matches, "queued")
          end
          [
            [::Sidekiq::ScheduledSet.new, "scheduled"],
            [::Sidekiq::RetrySet.new, "retrying"],
            [::Sidekiq::DeadSet.new, "dead"]
          ].each do |collection, state|
            scan(collection, wanted, matches, state)
          end

          links.map do |link|
            info = matches[link.active_job_id.to_s]
            Item.new(
              id: link.active_job_id.to_s,
              name: link.job_class_name.to_s,
              queue: link.queue_name.to_s,
              status: info ? info[:status] : "unavailable",
              created_at: link.created_at,
              scheduled_at: info && info[:scheduled_at],
              finished_at: nil
            )
          end
        end

        private

        def safe_queue_name?(value)
          value.is_a?(String) && value.match?(/\A[a-zA-Z0-9_.-]{1,80}\z/)
        end

        def scan(collection, wanted, matches, status)
          visited = 0
          collection.each do |job|
            break if visited >= @scan_limit
            visited += 1
            jid = job.jid.to_s
            next unless wanted.key?(jid)

            matches[jid] = {
              status: status,
              scheduled_at: status == "scheduled" || status == "retrying" ? job.at : nil
            }
          end
        end
      end
    end
  end
end

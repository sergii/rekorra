# frozen_string_literal: true

module Rekorra
  module AccessAudit
    module Adapters
      # The host owns the table and lifecycle; Core has no audit migrations.
      class ActiveRecord
        def initialize(model:)
          raise ConfigurationError, "Expected host model class name" unless
            model.is_a?(String) && model.match?(/\A[A-Z][A-Za-z0-9:]*\z/)
          @model_name = model
        end

        def write!(event:)
          raise ConfigurationError, "Invalid Audit Event" unless event.is_a?(Event)
          model.create!(tenant_key: event.tenant_key, actor_key: event.actor_key,
            record_type: event.record_type, record_id: event.record_id,
            action: event.action, request_id: event.request_id,
            occurred_at: event.occurred_at)
        end

        def entries(record:, tenant_key:, limit:)
          raise ConfigurationError, "Invalid audit query" unless
            limit.is_a?(Integer) && limit.between?(1, 30) &&
            tenant_key.is_a?(String) && !tenant_key.empty?
          model.where(tenant_key: tenant_key, record_type: record.class.name,
            record_id: record.id.to_s).order(occurred_at: :desc, id: :desc)
            .limit(limit).map do |row|
              Entry.new(actor_key: row.actor_key, action: row.action,
                occurred_at: row.occurred_at)
            end
        end

        private

        def model
          klass = @model_name.constantize
          raise ConfigurationError, "Audit model must inherit ActiveRecord" unless klass < ::ActiveRecord::Base
          klass
        end
      end
    end
  end
end

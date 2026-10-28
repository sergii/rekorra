# frozen_string_literal: true

module Rekorra
  module AccessAudit
    class Resolver
      def initialize(definition:, record:, tenant_key:, authorize:, registry:)
        @definition, @record, @tenant_key = definition, record, tenant_key
        @authorize, @registry = authorize, registry
      end

      def call
        return [] unless @definition
        return [] unless @authorize.call(@record, @definition.policy) == true
        items = @registry.fetch(@definition.source_name).entries(
          record: @record, tenant_key: @tenant_key, limit: @definition.page_size
        )
        unless items.is_a?(Array) && items.length <= @definition.page_size &&
            items.all? { |e| e.is_a?(Entry) && Event::ACTIONS.include?(e.action.to_s) &&
              e.occurred_at.is_a?(Time) && e.actor_key.is_a?(String) &&
              e.actor_key.bytesize.between?(1, 128) }
          raise ConfigurationError, "Access Audit adapter returned invalid entries"
        end
        items
      end
    end
  end
end

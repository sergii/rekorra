# frozen_string_literal: true

module Rekorra
  module Jobs
    class Resolver
      def initialize(resource:, record:, authorize:, registry:)
        @resource = resource
        @record = record
        @authorize = authorize
        @registry = registry
      end

      def call
        definition = @resource.jobs
        return [] unless definition
        return [] unless @authorize.call(@record, definition.policy) == true

        result = @registry.fetch(definition.source_name).jobs(
          record: @record, limit: definition.page_size
        )
        unless result.is_a?(Array) && result.length <= definition.page_size &&
            result.all? { |item| item.is_a?(Item) }
          raise ConfigurationError, "Jobs adapter returned invalid or unbounded results"
        end
        result
      end
    end
  end
end

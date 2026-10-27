# frozen_string_literal: true

module Rekorra
  module Findings
    class Resolver
      def initialize(resource:, record:, authorize:, registry:)
        @resource, @record = resource, record
        @authorize, @registry = authorize, registry
      end

      def call
        definition = @resource.findings
        return [] unless definition
        return [] unless @authorize.call(@record, definition.policy) == true

        definition.rule_names.filter_map do |name|
          @registry.fetch(name).evaluate(record: @record).tap do |result|
            unless result.nil? || result.is_a?(Finding)
              raise ConfigurationError, "Finding rule must return a Finding or nil"
            end
          end
        end.first(definition.page_size)
      end
    end
  end
end

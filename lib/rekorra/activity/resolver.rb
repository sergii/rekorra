# frozen_string_literal: true

module Rekorra
  module Activity
    class Resolver
      def initialize(resource:, record:, authorize:, registry:)
        @resource, @record = resource, record
        @authorize, @registry = authorize, registry
      end

      def call
        definition = @resource.activity
        return [] unless definition
        return [] unless @authorize.call(@record, definition.policy) == true

        @registry.fetch(definition.source_name).events(
          record: @record, fields: definition.visible_fields, limit: definition.page_size
        )
      end
    end
  end
end

# frozen_string_literal: true

module Rekorra
  module Context
    RecordDefinition = Struct.new(:name, :resource, :id, keyword_init: true)
    ExternalDefinition = Struct.new(:name, :provider, :instance, :kind, :id,
      :display_key, :policy, keyword_init: true)

    class Section
      MAX_REFERENCES = 20

      attr_reader :definitions

      def initialize
        @definitions = []
      end

      def record(name, resource:, id:)
        ensure_capacity!
        require_callback!(id)
        @definitions << RecordDefinition.new(
          name: name.to_sym, resource: resource.to_s, id: id
        ).freeze
      end

      def external(name, provider:, instance:, kind:, id:, authorize:, display_key: nil)
        ensure_capacity!
        require_callback!(id)
        require_callback!(display_key) unless display_key.nil?
        unless authorize.to_s.end_with?("?")
          raise ConfigurationError, "External context reference requires an explicit policy"
        end
        @definitions << ExternalDefinition.new(
          name: name.to_sym, provider: provider, instance: instance, kind: kind,
          id: id, display_key: display_key, policy: authorize.to_sym
        ).freeze
      end

      private

      def ensure_capacity!
        raise ConfigurationError, "Too many context references" if @definitions.length >= MAX_REFERENCES
      end

      def require_callback!(value)
        raise ConfigurationError, "Context IDs must be defined by callbacks" unless value.respond_to?(:call)
      end
    end
  end
end

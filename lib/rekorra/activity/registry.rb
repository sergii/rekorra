# frozen_string_literal: true

module Rekorra
  module Activity
    class Registry
      def initialize
        @adapters = {}
      end

      def register(name, adapter)
        unless adapter.respond_to?(:events)
          raise ConfigurationError, "Activity adapter must implement events"
        end
        @adapters[name.to_sym] = adapter
      end

      def fetch(name)
        @adapters.fetch(name.to_sym) do
          raise ConfigurationError, "Missing Activity adapter: #{name}"
        end
      end
    end
  end
end

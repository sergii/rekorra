# frozen_string_literal: true

module Rekorra
  module Jobs
    class Registry
      def initialize
        @adapters = {}
      end

      def register(name, adapter)
        raise ConfigurationError, "Jobs adapter must implement jobs" unless adapter.respond_to?(:jobs)
        @adapters[name.to_sym] = adapter
      end

      def fetch(name)
        @adapters.fetch(name.to_sym) { raise ConfigurationError, "Missing Jobs adapter: #{name}" }
      end
    end
  end
end

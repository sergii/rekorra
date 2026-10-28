# frozen_string_literal: true

module Rekorra
  module AccessAudit
    class Registry
      def initialize
        @adapters = {}
      end

      def register(name, adapter)
        unless adapter.respond_to?(:write!) && adapter.respond_to?(:entries)
          raise ConfigurationError, "Access Audit adapter needs write! and entries"
        end
        @adapters[name.to_sym] = adapter
      end

      def fetch(name)
        @adapters.fetch(name.to_sym) do
          raise ConfigurationError, "Missing Access Audit adapter: #{name}"
        end
      end
    end
  end
end

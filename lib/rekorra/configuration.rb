# frozen_string_literal: true

module Rekorra
  class Configuration
    attr_accessor :authenticate_with, :authorize_with, :scope_with

    def ready!
      missing = %i[authenticate_with authorize_with scope_with].reject do |name|
        public_send(name).respond_to?(:call)
      end
      raise ConfigurationError, "Missing security adapters: #{missing.join(', ')}" if missing.any?
    end
  end
end

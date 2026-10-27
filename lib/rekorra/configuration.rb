# frozen_string_literal: true

module Rekorra
  class Configuration
    attr_accessor :authenticate_with, :authorize_with, :scope_with
    attr_reader :resources

    def initialize
      @resources = {}
    end

    def resource(slug, class_name)
      key = slug.to_s
      raise ArgumentError, "Invalid resource slug" unless key.match?(/\A[a-z][a-z0-9_]*\z/)
      raise ArgumentError, "Expected a Resource class name" unless class_name.is_a?(String)

      @resources[key] = class_name
    end

    def ready!
      missing = %i[authenticate_with authorize_with scope_with].reject do |name|
        public_send(name).respond_to?(:call)
      end
      raise ConfigurationError, "Missing security adapters: #{missing.join(', ')}" if missing.any?
    end
  end
end

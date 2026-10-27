# frozen_string_literal: true

module Rekorra
  class Configuration
    attr_accessor :authenticate_with, :authorize_with, :scope_with
    attr_accessor :activity_actor_with
    attr_reader :activity_adapters, :job_adapters
    attr_accessor :context_application, :context_environment, :context_tenant_with
    attr_accessor :external_link_allowed_hosts
    attr_reader :resources, :external_services

    def initialize
      @resources = {}
      @activity_adapters = Activity::Registry.new
      @job_adapters = Jobs::Registry.new
      @external_services = {}
      @external_link_allowed_hosts = []
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

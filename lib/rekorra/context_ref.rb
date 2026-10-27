# frozen_string_literal: true

module Rekorra
  # A provider-neutral identity for a resource within one host app and tenant.
  # This is a value object; it never fetches records or grants access.
  class ContextRef
    attr_reader :application, :environment, :tenant, :resource, :id

    def initialize(application:, environment:, tenant:, resource:, id:)
      @application = required_string(application, :application)
      @environment = required_string(environment, :environment)
      @tenant = required_string(tenant, :tenant)
      @resource = required_string(resource, :resource)
      @id = required_string(id, :id)
      freeze
    end

    def to_h
      { application: application, environment: environment, tenant: tenant,
        resource: resource, id: id }
    end

    def ==(other)
      other.is_a?(ContextRef) && other.to_h == to_h
    end
    alias eql? ==

    def hash
      to_h.hash
    end

    private

    def required_string(value, field)
      string = value.to_s
      unless !string.strip.empty? && string.bytesize <= 256 && !string.match?(/[[:cntrl:]]/)
        raise ConfigurationError, "Invalid ContextRef #{field}"
      end
      string.dup.freeze
    end
  end
end

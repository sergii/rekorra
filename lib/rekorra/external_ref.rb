# frozen_string_literal: true

module Rekorra
  # Stable external identity. Provider-specific labels remain separate from IDs.
  # A reference is not a URL, token, API client or authorization grant.
  class ExternalRef
    attr_reader :provider, :instance, :kind, :id, :display_key

    def initialize(provider:, instance:, kind:, id:, display_key: nil)
      @provider = identifier(provider, :provider)
      @instance = required_string(instance, :instance)
      @kind = identifier(kind, :kind)
      @id = required_string(id, :id)
      @display_key = display_key.nil? ? @id : required_string(display_key, :display_key)
      freeze
    end

    def to_h
      { provider: provider, instance: instance, kind: kind,
        id: id, display_key: display_key }
    end

    def ==(other)
      other.is_a?(ExternalRef) && other.to_h == to_h
    end
    alias eql? ==

    def hash
      to_h.hash
    end

    private

    def identifier(value, field)
      string = value.to_s
      raise ConfigurationError, "Invalid ExternalRef #{field}" unless string.match?(/\A[a-z][a-z0-9_]*\z/)
      string.to_sym
    end

    def required_string(value, field)
      string = value.to_s
      unless !string.strip.empty? && string.bytesize <= 256 && !string.match?(/[[:cntrl:]]/)
        raise ConfigurationError, "Invalid ExternalRef #{field}"
      end
      string.dup.freeze
    end
  end
end

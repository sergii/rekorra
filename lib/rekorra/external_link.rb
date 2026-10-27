# frozen_string_literal: true

module Rekorra
  # Configuration for a provider link on an authorized resource.
  class ExternalLink
    PROVIDERS = %i[url sumo_logic].freeze

    attr_reader :name, :label, :provider, :policy, :options

    def initialize(name, label:, provider:, authorize:, **options)
      @name = name.to_sym
      @label = label.to_s
      @provider = provider.to_sym
      @policy = authorize.to_sym
      @options = options.freeze

      raise ConfigurationError, "External link needs a label" if label.to_s.empty?
      raise ConfigurationError, "Unknown external link provider: #{provider}" unless PROVIDERS.include?(@provider)
      raise ConfigurationError, "External link requires an explicit policy" unless @policy.to_s.end_with?("?")
    end
  end
end

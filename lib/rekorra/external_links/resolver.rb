# frozen_string_literal: true

require "uri"

module Rekorra
  module ExternalLinks
    Link = Struct.new(:name, :label, :provider, :url, keyword_init: true)

    # Resolves only links the current actor has permission to see.
    # It never fetches logs or communicates with an external service.
    class Resolver
      def initialize(resource:, record:, configuration:, authorize:)
        @resource = resource
        @record = record
        @configuration = configuration
        @authorize = authorize
      end

      def call
        @resource.external_links.filter_map do |definition|
          next unless @authorize.call(@record, definition.policy) == true

          url = build_url(definition)
          next unless url

          Link.new(name: definition.name, label: definition.label,
            provider: definition.provider, url: url)
        end
      end

      private

      def build_url(definition)
        settings = definition.options
        case definition.provider
        when :url
          base_url = settings.fetch(:base_url)
          path = settings.fetch(:path, "/")
          params = evaluate(settings.fetch(:params, {}))
        when :sumo_logic
          base_url = @configuration.external_services.dig(:sumo_logic, :base_url)
          return nil if base_url.nil?

          path = "/log-search/create"
          params = {
            query: evaluate(settings.fetch(:query)),
            startTime: evaluate(settings.fetch(:start_time, "-24h")),
            endTime: evaluate(settings.fetch(:end_time, "now"))
          }
        else
          raise ConfigurationError, "Unsupported provider: #{definition.provider}"
        end

        build_https_url(base_url, path, params)
      end

      def evaluate(value)
        value.respond_to?(:call) ? value.call(@record) : value
      end

      def build_https_url(base_url, path, params)
        base = URI.parse(base_url.to_s)
        hosts = @configuration.external_link_allowed_hosts.map(&:downcase)
        unless base.is_a?(URI::HTTPS) && base.host &&
            base.userinfo.nil? && base.query.nil? && base.fragment.nil? &&
            hosts.include?(base.host.downcase)
          raise ConfigurationError, "External link requires an allowed HTTPS base URL"
        end

        unless path.is_a?(String) && path.start_with?("/") &&
            !path.start_with?("//") && !path.match?(/[?#]/)
          raise ConfigurationError, "External link path must be a static absolute path"
        end

        unless params.is_a?(Hash) && params.all? { |key, value|
            (key.is_a?(String) || key.is_a?(Symbol)) &&
              (value.nil? || value.is_a?(String) || value.is_a?(Numeric) ||
                value == true || value == false)
          }
          raise ConfigurationError, "External link params must be scalar values"
        end

        uri = base.dup
        prefix = base.path.to_s.sub(%r{/+\z}, "")
        uri.path = "#{prefix}#{path}"
        uri.query = URI.encode_www_form(params.reject { |_key, value| value.nil? })
        uri.to_s
      rescue URI::InvalidURIError
        raise ConfigurationError, "Invalid external link base URL"
      end
    end
  end
end

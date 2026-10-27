# frozen_string_literal: true

require "digest"
require "json"

module Rekorra
  module Index
    # Opaque, authenticated, time-limited cursor. No Rails session storage,
    # external secrets or user-visible sort data in query-string tokens.
    class Cursor
      PURPOSE = "rekorra/resource-index/keyset/v1"
      MAX_BYTES = 4096
      TTL = 3600

      def initialize(context:)
        unless context.is_a?(String) && context.bytesize.between?(1, 512) && !context.strip.empty?
          raise ConfigurationError, "Keyset requires a stable nonempty host scope identity"
        end
        @context = context
      end

      def fingerprint(resource:, scope:, search:, filters:, sort:, direction:, per_page:)
        Digest::SHA256.hexdigest(JSON.generate({
          model: resource.model_class.name,
          resource: resource.name,
          scope: scope.to_sql,
          context: @context,
          search: search,
          filters: filters.sort.to_h,
          sort: sort,
          direction: direction,
          per_page: per_page
        }))
      end

      def encode(fingerprint:, edge:, sort_value:, primary_key:)
        encryptor.encrypt_and_sign({
          "v" => 1, "fingerprint" => fingerprint, "edge" => edge,
          "sort_value" => sort_value, "primary_key" => primary_key
        }, expires_in: TTL, purpose: PURPOSE)
      end

      def decode(token, fingerprint:)
        raise InvalidCursor unless token.is_a?(String) && token.bytesize.between?(1, MAX_BYTES)
        payload = encryptor.decrypt_and_verify(token, purpose: PURPOSE)
        unless payload.is_a?(Hash) && payload["v"] == 1 &&
            payload["fingerprint"] == fingerprint &&
            %w[after before].include?(payload["edge"]) &&
            !payload["sort_value"].nil? && !payload["primary_key"].nil?
          raise InvalidCursor
        end
        payload
      rescue ActiveSupport::MessageEncryptor::InvalidMessage, ArgumentError, TypeError
        raise InvalidCursor
      end

      private

      def encryptor
        secret = Rails.application.key_generator.generate_key(PURPOSE, 32)
        ActiveSupport::MessageEncryptor.new(secret,
          cipher: "aes-256-gcm", serializer: JSON)
      end
    end
  end
end

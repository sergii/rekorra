# frozen_string_literal: true

module Rekorra
  module AccessAudit
    # Only identity, time and operation. No attributes, params, cookies,
    # request body, raw exceptions or IP addresses are recorded by Core.
    class Event
      ACTIONS = %w[show create update destroy].freeze
      attr_reader :action, :record_type, :record_id, :actor_key, :tenant_key,
        :request_id, :occurred_at

      def initialize(action:, record_type:, record_id:, actor_key:, tenant_key:,
        request_id:, occurred_at:)
        @action = action.to_s.dup.freeze
        raise ConfigurationError, "Invalid Access Audit action" unless ACTIONS.include?(@action)
        @record_type = check(record_type, 120)
        @record_id = check(record_id, 128)
        @actor_key = check(actor_key, 128)
        @tenant_key = check(tenant_key, 128)
        @request_id = check(request_id, 128)
        raise ConfigurationError, "Invalid Access Audit time" unless occurred_at.is_a?(Time)
        @occurred_at = occurred_at
        freeze
      end

      private

      def check(value, max)
        unless value.is_a?(String) && value.bytesize.between?(1, max) &&
            !value.match?(/[[:cntrl:]]/)
          raise ConfigurationError, "Invalid Access Audit metadata"
        end
        value.dup.freeze
      end
    end

    Entry = Struct.new(:actor_key, :action, :occurred_at, keyword_init: true)
  end
end

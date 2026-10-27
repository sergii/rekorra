# frozen_string_literal: true

module Rekorra
  module Findings
    class Evidence
      attr_reader :label, :value

      def initialize(label:, value:)
        @label = safe_text(label, max: 80)
        @value = safe_text(value, max: 160)
        freeze
      end

      private

      def safe_text(value, max:)
        text = value.to_s
        unless !text.empty? && text.bytesize <= max &&
            !text.match?(/[[:cntrl:]]/)
          raise ConfigurationError, "Invalid finding evidence text"
        end
        text.dup.freeze
      end
    end

    class Finding
      SEVERITIES = %w[info warning critical].freeze

      attr_reader :code, :severity, :title, :description, :evidence

      def initialize(code:, severity:, title:, description:, evidence:)
        @code = code.to_s.dup.freeze
        @severity = severity.to_s.dup.freeze
        @title = title.to_s.dup.freeze
        @description = description.to_s.dup.freeze
        @evidence = Array(evidence).dup.freeze
        unless code.to_s.match?(/\A[a-z][a-z0-9_]*\z/) &&
            SEVERITIES.include?(severity.to_s) &&
            valid_text?(@title, 120) && valid_text?(@description, 300) &&
            @evidence.size.between?(1, 8) && @evidence.all? { |item| item.is_a?(Evidence) }
          raise ConfigurationError, "Invalid finding payload"
        end
        freeze
      end

      private

      def valid_text?(text, max)
        !text.empty? && text.bytesize <= max && !text.match?(/[[:cntrl:]]/)
      end
    end
  end
end

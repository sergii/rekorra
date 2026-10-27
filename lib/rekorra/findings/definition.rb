# frozen_string_literal: true

module Rekorra
  module Findings
    class Definition
      attr_reader :rule_names, :policy, :page_size

      def initialize
        @rule_names = []
        @page_size = 10
      end

      def rule(name)
        key = name.to_s
        raise ConfigurationError, "Invalid Findings rule" unless key.match?(/\A[a-z][a-z0-9_]*\z/)
        raise ConfigurationError, "Too many Findings rules" if @rule_names.length >= 20
        raise ConfigurationError, "Duplicate Findings rule" if @rule_names.include?(key.to_sym)

        @rule_names << key.to_sym
      end

      def authorize(value)
        @policy = value.to_sym
      end

      def limit(value)
        @page_size = Integer(value)
      end

      def validate!
        unless rule_names.any? && policy && policy.to_s.end_with?("?")
          raise ConfigurationError, "Findings require rules and explicit authorization"
        end
        unless page_size.between?(1, 30)
          raise ConfigurationError, "Findings limit must be between 1 and 30"
        end
      end
    end
  end
end

# frozen_string_literal: true

module Rekorra
  module Findings
    class Registry
      def initialize
        @rules = {}
      end

      def register(name, evaluator)
        raise ConfigurationError, "Finding rule must implement evaluate(record:)" unless evaluator.respond_to?(:evaluate) || evaluator.is_a?(String)
        key = name.to_s
        raise ConfigurationError, "Invalid Findings rule name" unless key.match?(/\A[a-z][a-z0-9_]*\z/)
        @rules[key.to_sym] = evaluator
      end

      def fetch(name)
        entry = @rules.fetch(name.to_sym) { raise ConfigurationError, "Missing Findings rule: #{name}" }
        rule = entry.is_a?(String) ? entry.constantize.new : entry
        unless rule.respond_to?(:evaluate)
          raise ConfigurationError, "Finding rule must implement evaluate(record:)"
        end
        rule
      end
    end
  end
end

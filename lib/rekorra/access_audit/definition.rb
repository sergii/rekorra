# frozen_string_literal: true

module Rekorra
  module AccessAudit
    class Definition
      attr_reader :source_name, :policy, :page_size

      def initialize
        @page_size = 10
      end

      def source(name)
        @source_name = name.to_sym
      end

      def authorize(value)
        @policy = value.to_sym
      end

      def limit(number)
        @page_size = Integer(number)
      end

      def validate!
        raise ConfigurationError, "Access Audit requires source and read policy" unless
          source_name && policy && policy.to_s.end_with?("?")
        raise ConfigurationError, "Access Audit limit must be 1..30" unless page_size.between?(1, 30)
      end
    end
  end
end

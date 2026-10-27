# frozen_string_literal: true

module Rekorra
  module Jobs
    class Definition
      attr_reader :source_name, :policy, :page_size

      def initialize
        @page_size = 10
      end

      def source(name)
        @source_name = name.to_sym
      end

      def authorize(name)
        @policy = name.to_sym
      end

      def limit(size)
        @page_size = Integer(size)
      end

      def validate!
        unless source_name && policy && policy.to_s.end_with?("?")
          raise ConfigurationError, "Jobs require a named source and explicit authorization"
        end
        raise ConfigurationError, "Jobs limit must be 1..30" unless page_size.between?(1, 30)
      end
    end
  end
end

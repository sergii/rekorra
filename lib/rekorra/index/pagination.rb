# frozen_string_literal: true

module Rekorra
  module Index
    class Pagination
      HARD_MAX_PER_PAGE = 100

      attr_reader :strategy, :default_per_page, :maximum_per_page

      def initialize
        @strategy = :offset
        @default_per_page = 25
        @maximum_per_page = HARD_MAX_PER_PAGE
      end

      def strategy(value)
        raise ConfigurationError, "Only offset pagination is implemented" unless value.to_sym == :offset
        @strategy = :offset
      end

      def per_page(value)
        @default_per_page = Integer(value)
      end

      def max_per_page(value)
        @maximum_per_page = Integer(value)
      end

      def validate!
        unless @maximum_per_page.between?(1, HARD_MAX_PER_PAGE) &&
            @default_per_page.between?(1, @maximum_per_page)
          raise ConfigurationError, "Invalid Index page size; maximum is #{HARD_MAX_PER_PAGE}"
        end
      end

      def sizes
        ([10, 25, 50, 100, default_per_page].uniq.select { |n| n <= maximum_per_page }).sort
      end
    end
  end
end

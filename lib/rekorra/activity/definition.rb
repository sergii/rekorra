# frozen_string_literal: true

module Rekorra
  module Activity
    # Resource-level, opt-in presentation contract for historical events.
    class Definition
      attr_reader :source_name, :policy, :visible_fields, :page_size

      def initialize
        @visible_fields = []
        @page_size = 10
      end

      def source(name)
        @source_name = name.to_sym
      end

      def fields(*names)
        @visible_fields = names.map(&:to_s).uniq.freeze
      end

      def authorize(policy)
        @policy = policy.to_sym
      end

      def limit(number)
        @page_size = Integer(number)
      end

      def validate!(model)
        unless source_name && policy&.to_s&.end_with?("?") && visible_fields.any?
          raise ConfigurationError, "Activity requires source, explicit authorization and fields"
        end
        unless page_size.between?(1, 30)
          raise ConfigurationError, "Activity limit must be between 1 and 30"
        end
        unknown = visible_fields - model.column_names
        raise ConfigurationError, "Unknown Activity fields: #{unknown.join(', ')}" if unknown.any?
      end
    end
  end
end

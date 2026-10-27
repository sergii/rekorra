# frozen_string_literal: true

module Rekorra
  module Index
    class Filter
      TYPES = %i[select boolean date_range number_range].freeze

      attr_reader :name, :type, :label, :options

      def initialize(name, type:, options: nil, label: nil)
        @name = name.to_s.freeze
        @type = type.to_sym
        @label = (label || @name.humanize).to_s.freeze
        @options = normalize_options(options).freeze

        unless @name.match?(/\A[a-z][a-z0-9_]*\z/) && TYPES.include?(@type)
          raise ConfigurationError, "Invalid Index filter name/type"
        end
        if @type == :select && @options.empty?
          raise ConfigurationError, "Select filter requires explicit choices"
        end
        if @type != :select && !@options.empty?
          raise ConfigurationError, "Only select filters can have options"
        end
      end

      def validate!(model)
        column = model.columns_hash[@name]
        raise ConfigurationError, "Unknown Index filter #{@name}" unless column

        valid = case type
        when :select then %i[string text integer]
        when :boolean then %i[boolean]
        when :date_range then %i[date datetime timestamp]
        when :number_range then %i[integer bigint decimal float]
        end
        unless valid.include?(column.type)
          raise ConfigurationError, "Filter #{@name} is incompatible with #{column.type}"
        end
      end

      def values
        @options.map(&:last)
      end

      private

      def normalize_options(options)
        Array(options).map do |value|
          label, key = value.is_a?(Array) && value.length == 2 ? value : [value, value]
          unless [label, key].all? { |item| item.is_a?(String) || item.is_a?(Symbol) || item.is_a?(Numeric) }
            raise ConfigurationError, "Filter options must be static scalar values"
          end
          [label.to_s.freeze, key.to_s.freeze].freeze
        end
      end
    end
  end
end

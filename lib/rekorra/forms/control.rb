# frozen_string_literal: true

module Rekorra
  module Forms
    # Defines native HTML controls from the actual host ActiveRecord column.
    # A matching server-side predicate rejects malformed structured input
    # before ActiveRecord can silently coerce it into another value.
    class Control
      def initialize(model:, field:)
        @model, @field = model, field
      end

      def kind
        return :enum if @field.type == :enum

        case @model.type_for_attribute(@field.name.to_s).type
        when :boolean then :boolean
        when :date then :date
        when :datetime, :timestamp then :datetime
        when :integer, :bigint then :integer
        when :decimal, :float then :decimal
        when :text then :text
        else :string
        end
      end

      def valid_value?(value)
        return true if kind == :enum || %i[string text].include?(kind)
        return false unless value.is_a?(String)
        return column&.null == true if value.empty?

        case kind
        when :boolean then %w[0 1 true false].include?(value)
        when :integer then value.match?(/\A-?\d{1,20}\z/)
        when :decimal then valid_decimal?(value)
        when :date then valid_date?(value)
        when :datetime then valid_datetime?(value)
        else false
        end
      end

      private

      def column
        @model.columns_hash[@field.name.to_s]
      end

      def valid_decimal?(value)
        return false unless value.bytesize <= 64 &&
          value.match?(/\A-?\d{1,30}(?:\.\d{1,20})?\z/)
        return true unless column&.precision && column&.scale

        whole, fraction = value.delete_prefix("-").split(".", 2)
        nonzero_whole_digits = whole.sub(/\A0+/, "").length
        nonzero_whole_digits <= column.precision - column.scale &&
          (fraction.nil? || fraction.length <= column.scale)
      end

      def valid_date?(value)
        value.match?(/\A\d{4}-\d{2}-\d{2}\z/) && Date.iso8601(value)
      rescue Date::Error
        false
      end

      def valid_datetime?(value)
        value.match?(/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}(?::\d{2})?\z/) &&
          DateTime.iso8601(value)
      rescue Date::Error
        false
      end
    end
  end
end

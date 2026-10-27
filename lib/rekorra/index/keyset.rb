# frozen_string_literal: true

module Rekorra
  module Index
    # Two-field lexicographic seek: requested sort column + PK ascending
    # tie-breaker. Supports non-NULL scalar sort fields only (enforced by DSL).
    class Keyset
      Result = Struct.new(:records, :has_next, :has_previous, :next_cursor,
        :previous_cursor, keyword_init: true)

      def initialize(relation:, model:, sort:, direction:, per_page:, token:, codec:, fingerprint:)
        @relation, @model, @sort, @direction = relation, model, sort, direction
        @per_page, @codec, @fingerprint = per_page, codec, fingerprint
        @primary = model.primary_key
        @boundary = token.nil? ? nil : codec.decode(token, fingerprint: fingerprint)
      end

      def call
        backward = @boundary && @boundary["edge"] == "before"
        relation = @boundary ? @relation.where(predicate(backward: backward)) : @relation
        query = relation.reorder(*order_for(backward: backward))
        rows = query.limit(@per_page + 1).to_a
        has_extra = rows.length > @per_page
        current = rows.first(@per_page)
        current.reverse! if backward

        has_previous = backward ? has_extra : !@boundary.nil?
        has_next = backward ? !@boundary.nil? : has_extra
        Result.new(
          records: current,
          has_previous: has_previous,
          has_next: has_next,
          previous_cursor: has_previous && current.any? ? boundary_for(current.first, "before") : nil,
          next_cursor: has_next && current.any? ? boundary_for(current.last, "after") : nil
        )
      end

      private

      def order_for(backward:)
        descending = @direction == "desc"
        descending = !descending if backward
        table = @model.arel_table
        first = descending ? table[@sort].desc : table[@sort].asc
        return [first] if @sort == @primary

        tie = backward ? table[@primary].desc : table[@primary].asc
        [first, tie]
      end

      def predicate(backward:)
        table = @model.arel_table
        value = cast(@sort, @boundary["sort_value"])
        primary_value = cast(@primary, @boundary["primary_key"])
        sort_op = @direction == "asc" ? :gt : :lt
        sort_op = sort_op == :gt ? :lt : :gt if backward
        condition = table[@sort].public_send(sort_op, value)
        return condition if @sort == @primary

        tie_op = backward ? :lt : :gt
        condition.or(table[@sort].eq(value).and(table[@primary].public_send(tie_op, primary_value)))
      end

      def cast(column, value)
        type = @model.type_for_attribute(column)
        unless value.is_a?(String) || value.is_a?(Numeric) || value == true || value == false
          raise InvalidCursor
        end
        typed = type.cast(value)
        raise InvalidCursor if typed.nil?
        typed
      rescue ArgumentError, TypeError, RangeError
        raise InvalidCursor
      end

      def boundary_for(record, edge)
        sort_value = normalized_value(record.public_send(@sort))
        primary_value = normalized_value(record.public_send(@primary))
        @codec.encode(fingerprint: @fingerprint, edge: edge,
          sort_value: sort_value, primary_key: primary_value)
      end

      def normalized_value(value)
        case value
        when Time, DateTime then value.iso8601(6)
        when Date then value.iso8601
        when BigDecimal then value.to_s("F")
        when String, Integer, Float, TrueClass, FalseClass then value
        else raise ConfigurationError, "Unsupported keyset boundary type"
        end
      end
    end
  end
end

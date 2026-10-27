# frozen_string_literal: true

module Rekorra
  # Bounded queries for any Resource Index; the host owns the SQL-level scope.
  class Query
    PAGE_SIZE = 25
    MAX_PAGE = 10_000

    attr_reader :page, :sort, :direction, :search, :has_next, :per_page,
      :filter_values, :sort_columns

    def initialize(resource:, scope:, search:, sort:, direction:, page:, per_page: nil, filters: nil)
      @resource, @scope = resource, scope
      @search = search.is_a?(String) ? search.strip.first(160) : ""
      @page = [[Integer(page, exception: false) || 1, 1].max, MAX_PAGE].min
      @direction = direction == "desc" ? "desc" : "asc"
      @has_next = false

      settings = resource.index.pagination
      settings.validate!
      size = Integer(per_page, exception: false)
      @per_page = size && size.between?(1, settings.maximum_per_page) ?
        size : settings.default_per_page

      model = resource.model_class
      @sort_columns = if resource.index.sort_columns.any?
        resource.index.sort_columns
      else
        resource.index.fields.map(&:name).map(&:to_s) & model.column_names
      end
      @sort = @sort_columns.include?(sort.to_s) ? sort.to_s : model.primary_key.to_s
      @raw_filters = filters.is_a?(Hash) || filters.is_a?(ActionController::Parameters) ? filters : {}
      @filter_values = {}
    end

    def navigation_params
      args = { q: search, sort: sort, direction: direction, per_page: per_page }
      args[:filters] = filter_values unless filter_values.empty?
      args
    end

    def call
      model = @resource.model_class
      unless @scope.is_a?(ActiveRecord::Relation) && @scope.klass == model
        raise ConfigurationError, "Resource Query requires a model-scoped relation"
      end
      relation = apply_filters(apply_search(@scope, model), model)
      table, primary = model.arel_table, model.primary_key
      order = direction == "desc" ? table[sort].desc : table[sort].asc
      relation = relation.reorder(order)
      relation = relation.order(table[primary].asc) unless sort == primary

      rows = relation.limit(per_page + 1).offset((page - 1) * per_page).to_a
      @has_next = rows.length > per_page
      rows.first(per_page)
    end

    private

    def apply_search(relation, model)
      names = @resource.index.index_search_columns || @resource.search_by.map(&:to_s)
      names = names.select { |name|
        column = model.columns_hash[name.to_s]
        column && %i[string text].include?(column.type)
      }
      return relation if search.empty? || names.empty?

      pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search)}%"
      table = model.arel_table
      conditions = names.map { |name| table[name].matches(pattern) }
      relation.where(conditions.reduce { |left, right| left.or(right) })
    end

    def apply_filters(relation, model)
      table = model.arel_table
      @resource.index.filters.each do |filter|
        name = filter.name
        column = model.columns_hash.fetch(name)
        case filter.type
        when :select
          v = param(name)
          next unless v && filter.values.include?(v)
          @filter_values[name] = v
          relation = relation.where(name => v)
        when :boolean
          v = param(name)
          next unless %w[true false].include?(v)
          @filter_values[name] = v
          relation = relation.where(name => v == "true")
        when :date_range
          from = parse_date(param("#{name}_from"))
          to = parse_date(param("#{name}_to"))
          if from
            @filter_values["#{name}_from"] = from.iso8601
            floor = column.type == :date ? from : from.in_time_zone.beginning_of_day
            relation = relation.where(table[name].gteq(floor))
          end
          if to
            @filter_values["#{name}_to"] = to.iso8601
            ceiling = column.type == :date ? to.next_day : to.next_day.in_time_zone.beginning_of_day
            relation = relation.where(table[name].lt(ceiling))
          end
        when :number_range
          %w[min max].each do |boundary|
            key = "#{name}_#{boundary}"
            value = parse_number(param(key), integer: %i[integer bigint].include?(column.type))
            next unless value
            @filter_values[key] = value.to_s
            relation = relation.where(boundary == "min" ?
              table[name].gteq(value) : table[name].lteq(value))
          end
        end
      end
      relation
    end

    def param(key)
      value = @raw_filters[key] || @raw_filters[key.to_sym]
      value.is_a?(String) && value.bytesize <= 128 ? value : nil
    end

    def parse_date(text)
      return unless text&.match?(/\A\d{4}-\d{2}-\d{2}\z/)
      Date.iso8601(text)
    rescue Date::Error
      nil
    end

    def parse_number(text, integer:)
      return unless text && text.bytesize <= 24
      pattern = integer ? /\A-?\d{1,18}\z/ : /\A-?\d{1,18}(?:\.\d{1,5})?\z/
      return unless text.match?(pattern)
      integer ? Integer(text) : BigDecimal(text)
    rescue ArgumentError
      nil
    end
  end
end

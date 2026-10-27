# frozen_string_literal: true

module Rekorra
  class Query
    PAGE_SIZE = 25
    MAX_PAGE = 10_000

    attr_reader :page, :sort, :direction, :search, :has_next

    def initialize(resource:, scope:, search:, sort:, direction:, page:)
      @resource = resource
      @scope = scope
      @search = search.to_s.strip.first(160)
      @page = [[Integer(page, exception: false) || 1, 1].max, MAX_PAGE].min
      @sort = sort.to_s
      @direction = direction == "desc" ? "desc" : "asc"
      @has_next = false
    end

    def call
      model = @resource.model_class
      relation = @scope
      searchable = @resource.search_by.filter_map do |name|
        column = model.columns_hash[name.to_s]
        name if column && %i[string text].include?(column.type)
      end
      if @search.present? && searchable.any?
        escaped = ActiveRecord::Base.sanitize_sql_like(@search)
        table = model.arel_table
        conditions = searchable.map { |name| table[name].matches("%#{escaped}%") }
        relation = relation.where(conditions.reduce { |left, right| left.or(right) })
      end

      sortable = @resource.index.fields.map(&:name).map(&:to_s) & model.column_names
      column = sortable.include?(@sort) ? @sort : model.primary_key
      table = model.arel_table
      primary = model.primary_key
      order = @direction == "desc" ? table[column].desc : table[column].asc
      relation = relation.reorder(order)
      relation = relation.order(table[primary].asc) unless column == primary
      items = relation.limit(PAGE_SIZE + 1).offset((@page - 1) * PAGE_SIZE).to_a
      @has_next = items.length > PAGE_SIZE
      items.first(PAGE_SIZE)
    end
  end
end

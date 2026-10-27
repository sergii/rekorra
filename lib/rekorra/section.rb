# frozen_string_literal: true

module Rekorra
  class Section
    attr_reader :fields, :associations

    def initialize
      @fields = []
      @associations = []
      @filters = []
      @sort_columns = []
      @index_search_columns = nil
      @pagination = Index::Pagination.new
    end

    def field(name, as: :auto, **options)
      @fields << Field.new(name: name.to_sym, type: as.to_sym, options: options)
    end

    attr_reader :filters, :sort_columns

    def filter(name, type:, **options)
      definition = Index::Filter.new(name, type: type, **options)
      raise ConfigurationError, "Duplicate Index filter" if @filters.any? { |item| item.name == definition.name }

      @filters << definition
    end

    def sort_by(*names)
      @sort_columns = names.map(&:to_s).uniq
    end

    def search_by(*names)
      @index_search_columns = names.map(&:to_s).uniq
    end

    def index_search_columns
      @index_search_columns
    end

    def pagination(&block)
      @pagination.instance_eval(&block) if block
      @pagination
    end

    def validate_index!(model)
      pagination.validate!
      filters.each { |definition| definition.validate!(model) }
      invalid = sort_columns - model.column_names
      raise ConfigurationError, "Unknown Index sort columns: #{invalid.join(', ')}" if invalid.any?
      if index_search_columns
        invalid = index_search_columns.reject do |name|
          model.columns_hash[name] && %i[string text].include?(model.columns_hash[name].type)
        end
        raise ConfigurationError, "Invalid Index search columns: #{invalid.join(', ')}" if invalid.any?
      end
    end

    def association(name)
      @associations << name.to_sym
    end
  end
end

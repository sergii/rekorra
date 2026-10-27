# frozen_string_literal: true

module Rekorra
  class Section
    attr_reader :fields, :associations

    def initialize
      @fields = []
      @associations = []
    end

    def field(name, as: :auto, **options)
      @fields << Field.new(name: name.to_sym, type: as.to_sym, options: options)
    end

    def association(name)
      @associations << name.to_sym
    end
  end
end

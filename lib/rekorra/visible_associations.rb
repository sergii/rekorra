# frozen_string_literal: true

module Rekorra
  class VisibleAssociations
    def initialize(records:, fields:, scope_with:, authorize_with:, actor:)
      @records, @fields = records, fields
      @scope_with, @authorize_with, @actor = scope_with, authorize_with, actor
    end

    def call
      return {} if @records.empty?

      @fields.each_with_object({}) do |field, output|
        reflection = @records.first.class.reflect_on_association(field.name)
        next unless reflection&.belongs_to? && !reflection.polymorphic?

        ids = @records.filter_map { |record| record.public_send(reflection.foreign_key) }.uniq
        next if ids.empty?

        model = reflection.klass
        scope = @scope_with.call(@actor, model)
        unless scope.is_a?(ActiveRecord::Relation) && scope.klass == model
          raise ConfigurationError, "Scope adapter must return a relation for #{model}"
        end
        visible = scope.where(model.primary_key => ids).select do |record|
          @authorize_with.call(@actor, record, :show?) == true
        end
        output[field.name] = visible.index_by { |record| record.public_send(model.primary_key).to_s }
      end
    end
  end
end

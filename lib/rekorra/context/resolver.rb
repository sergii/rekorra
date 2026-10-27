# frozen_string_literal: true

module Rekorra
  module Context
    Entry = Struct.new(:name, :reference, :label, :resource_slug, :record_id,
      keyword_init: true)

    # The host owns authorization and scopes. No linked record is exposed by ID
    # alone, and a denied external reference does not evaluate its callbacks.
    class Resolver
      def initialize(resource:, record:, actor:, configuration:, authorize:, scope:)
        @resource, @record, @actor = resource, record, actor
        @configuration, @authorize, @scope = configuration, authorize, scope
      end

      def call
        @resource.context.definitions.filter_map do |definition|
          case definition
          when RecordDefinition then resolve_record(definition)
          when ExternalDefinition then resolve_external(definition)
          else raise ConfigurationError, "Unknown context definition"
          end
        end
      end

      private

      def resolve_record(definition)
        resource = Rekorra.resource_for(definition.resource)
        model = resource.model_class
        return nil unless @authorize.call(model, :show?) == true

        id = definition.id.call(@record)
        return nil if id.nil? || id.to_s.empty?

        # The scope callback is validated by the controller's scoped_for helper.
        # Query the scope, never the model, to avoid cross-tenant disclosures.
        scoped = @scope.call(model)
        unless scoped.is_a?(ActiveRecord::Relation) && scoped.klass == model
          raise ConfigurationError, "Context scope must return a relation for #{model}"
        end
        target = scoped.find_by(model.primary_key => id)
        return nil unless target && @authorize.call(target, :show?) == true

        reference = ContextRef.new(
          application: @configuration.context_application,
          environment: @configuration.context_environment,
          tenant: @configuration.context_tenant_with.call(@actor),
          resource: definition.resource,
          id: target.public_send(model.primary_key)
        )
        title = if target.respond_to?(:name)
          target.name
        elsif target.respond_to?(:number)
          target.number
        else
          "##{target.to_param}"
        end
        Entry.new(name: definition.name, reference: reference,
          label: "#{definition.name.to_s.humanize}: #{title}",
          resource_slug: definition.resource, record_id: target.to_param)
      end

      def resolve_external(definition)
        return nil unless @authorize.call(@record, definition.policy) == true

        id = definition.id.call(@record)
        return nil if id.nil? || id.to_s.empty?

        display = definition.display_key&.call(@record)
        reference = ExternalRef.new(
          provider: definition.provider, instance: definition.instance,
          kind: definition.kind, id: id, display_key: display
        )
        Entry.new(name: definition.name, reference: reference,
          label: "#{reference.provider.to_s.humanize} #{reference.kind}: #{reference.display_key}")
      end
    end
  end
end

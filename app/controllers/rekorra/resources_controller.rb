# frozen_string_literal: true

module Rekorra
  class ResourcesController < ApplicationController
    before_action :load_resource
    before_action :load_record, only: %i[show edit update destroy]

    def index
      authorize!(@model, :index?)
      keyset = @resource.index.pagination.strategy == :keyset
      identity = if keyset
        callback = Rekorra.configuration.index_cursor_context_with
        raise ConfigurationError, "Missing index cursor context adapter" unless callback.respond_to?(:call)
        callback.call(rekorra_actor)
      end
      @denied_columns = @resource.field_policies.filter_map do |column, rules|
        column if rules[:read] && !allowed?(@model, rules[:read])
      end
      @index_fields = @resource.index.fields.reject { |field| @denied_columns.include?(field.name.to_s) }
      @index_filters = @resource.index.filters.reject { |filter| @denied_columns.include?(filter.name) }
      @query = Query.new(resource: @resource, scope: scoped_for(@model),
        search: params[:q], sort: params[:sort], direction: params[:direction],
        page: params[:page], per_page: params[:per_page], filters: params[:filters],
        cursor: params[:cursor], cursor_context: identity,
        denied_columns: @denied_columns)
      @records = @query.call.select { |item| allowed?(item, :show?) }
      @visible_associations = visible_associations(@records, @index_fields)
    end

    def show
      authorize!(@record, :show?)
      @findings_visible = @resource.findings && allowed?(@record, @resource.findings.policy)
      @finding_items = Findings::Resolver.new(
        resource: @resource, record: @record,
        authorize: ->(subject, action) { allowed?(subject, action) },
        registry: Rekorra.configuration.finding_rules
      ).call
      @jobs_visible = @resource.jobs && allowed?(@record, @resource.jobs.policy)
      @job_items = Jobs::Resolver.new(
        resource: @resource, record: @record,
        authorize: ->(subject, action) { allowed?(subject, action) },
        registry: Rekorra.configuration.job_adapters
      ).call
      @activity_visible = @resource.activity && allowed?(@record, @resource.activity.policy)
      @activity_events = Activity::Resolver.new(
        resource: @resource, record: @record,
        authorize: ->(subject, action) { allowed?(subject, action) },
        registry: Rekorra.configuration.activity_adapters
      ).call
      @show_fields = @resource.show.fields.select { |field| field_readable?(@record, field) }
      @visible_associations = visible_associations([@record], @show_fields)
      @context_entries = Context::Resolver.new(
        resource: @resource, record: @record, actor: rekorra_actor,
        configuration: Rekorra.configuration,
        authorize: ->(subject, action) { allowed?(subject, action) },
        scope: ->(model) { scoped_for(model) }
      ).call
      @external_links = ExternalLinks::Resolver.new(
        resource: @resource, record: @record, configuration: Rekorra.configuration,
        authorize: ->(record, policy) { allowed?(record, policy) }
      ).call
      @related = {}
      @resource.show.associations.each do |association|
        reflection = @model.reflect_on_association(association)
        next unless reflection.collection? && !reflection.polymorphic?

        relation = scoped_for(reflection.klass).merge(@record.public_send(association))
        @related[association] = relation.limit(6).to_a.select { |item| allowed?(item, :show?) }
      end
    end

    def new
      authorize!(@model, :create?)
      @record = @model.new
      load_field_options
    end

    def create
      authorize!(@model, :create?)
      @record = @model.new
      authorize!(@record, :create?)
      @record.assign_attributes(record_params)
      validate_foreign_keys!
      if with_activity_actor { @record.save }
        redirect_to record_path(slug: params[:slug], id: @record.to_param), notice: "Created"
      else
        load_field_options
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize!(@record, :edit?)
      load_field_options
    end

    def update
      authorize!(@record, :update?)
      @record.assign_attributes(record_params)
      authorize!(@record, :update?)
      validate_foreign_keys!
      if with_activity_actor { @record.save }
        redirect_to record_path(slug: params[:slug], id: @record.to_param), notice: "Updated"
      else
        load_field_options
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize!(@record, :destroy?)
      with_activity_actor { @record.destroy! }
      redirect_to records_path(slug: params[:slug]), notice: "Deleted", status: :see_other
    end

    private

    def with_activity_actor(&block)
      definition = @resource.activity
      return yield unless definition

      adapter = Rekorra.configuration.activity_adapters.fetch(definition.source_name)
      return yield unless adapter.respond_to?(:with_actor)

      identify = Rekorra.configuration.activity_actor_with
      raise ConfigurationError, "Activity actor callback missing" unless identify.respond_to?(:call)

      adapter.with_actor(actor: identify.call(rekorra_actor), &block)
    end

    def load_resource
      @resource = Rekorra.resource_for(params[:slug])
      @resource.validate!
      @model = @resource.model_class
    end

    def load_record
      @record = scoped_for(@model).find(params[:id])
    end

    def record_params
      submitted = params.require(:record)
      @resource.permitted_fields.each do |name|
        next unless submitted.key?(name)
        raise NotAuthorized unless field_writable?(@record, name)
      end
      submitted.permit(*@resource.permitted_fields.select { |name| field_writable?(@record, name) })
    end

    def field_readable?(record, field)
      policy = @resource.policy_for(field.name, :read)
      !policy || (allowed?(@model, policy) && allowed?(record, policy))
    end

    def field_writable?(record, name)
      policy = @resource.policy_for(name, :write)
      !policy || (allowed?(@model, policy) && allowed?(record, policy))
    end

    def validate_foreign_keys!
      @resource.form.fields.each do |field|
        reflection = @model.reflect_on_all_associations(:belongs_to).find do |entry|
          !entry.polymorphic? && entry.foreign_key == field.name.to_s
        end
        next unless reflection

        foreign_id = @record.public_send(reflection.foreign_key)
        next if foreign_id.blank?

        related_model = reflection.klass
        permitted = scoped_for(related_model).where(related_model.primary_key => foreign_id).exists?
        raise NotAuthorized unless permitted
      end
    end

    def load_field_options
      @form_fields = @resource.form.fields.select do |field|
        field_readable?(@record, field) && field_writable?(@record, field.name)
      end
      @field_options = {}
      @form_fields.each do |field|
        reflection = @model.reflect_on_all_associations(:belongs_to).find do |entry|
          !entry.polymorphic? && entry.foreign_key == field.name.to_s
        end
        next unless reflection

        candidates = scoped_for(reflection.klass).limit(100).to_a
        @field_options[field.name] = candidates.select { |item| allowed?(item, :show?) }.map do |item|
          [item.respond_to?(:name) ? item.name : item.to_param, item.id]
        end
      end
    end

    def visible_associations(records, fields)
      VisibleAssociations.new(records: records, fields: fields,
        scope_with: Rekorra.configuration.scope_with,
        authorize_with: Rekorra.configuration.authorize_with,
        actor: rekorra_actor).call
    end
  end
end

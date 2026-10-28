# frozen_string_literal: true

module Rekorra
  class ResourcesController < ApplicationController
    helper_method :field_readable?

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
        definition = @resource.form.fields.find { |item| item.name.to_s == name.to_s }
        if definition&.type == :enum
          value = submitted[name]
          allowed_values = @model.defined_enums.fetch(name.to_s).keys
          raise NotAuthorized unless value.is_a?(String) &&
            (value.empty? || allowed_values.include?(value))
        elsif definition
          control = Forms::Control.new(model: @model, field: definition)
          raise NotAuthorized unless control.valid_value?(submitted[name])
        end
      end
      submitted.permit(*@resource.permitted_fields.select { |name| field_writable?(@record, name) })
    end

    def field_readable?(record, field)
      policy = @resource.policy_for(field.name, :read)
      !policy || (allowed?(@model, policy) && allowed?(record, policy))
    end

    def field_writable?(record, name)
      field = @resource.form.fields.find { |entry| entry.name.to_s == name.to_s }
      return false unless field && field_readable?(record, field)

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
      @association_searches = {}
      @form_fields.each do |field|
        reflection = @model.reflect_on_all_associations(:belongs_to).find do |entry|
          !entry.polymorphic? && entry.foreign_key == field.name.to_s
        end
        next unless reflection

        model = reflection.klass
        raw = params[:association_q]
        value = raw.is_a?(ActionController::Parameters) ? raw[field.name.to_s] : nil
        search = value.is_a?(String) ? value.strip.first(80) : ""
        @association_searches[field.name] = search
        relation = scoped_for(model)
        if search.present?
          column = %w[name email number].find do |name|
            col = model.columns_hash[name]
            col && %i[string text].include?(col.type)
          end
          if column
            pattern = "%#{ActiveRecord::Base.sanitize_sql_like(search)}%"
            relation = relation.where(model.arel_table[column].matches(pattern, "\\"))
          else
            relation = relation.none
          end
        end

        candidates = relation.reorder(model.primary_key => :asc).limit(50).to_a
        foreign_id = @record.public_send(reflection.foreign_key)
        if foreign_id.present?
          selected = scoped_for(model).find_by(model.primary_key => foreign_id)
          candidates << selected if selected && !candidates.any? { |item| item.id == selected.id }
        end
        @field_options[field.name] = candidates.select do |item|
          allowed?(item, :show?)
        end.map do |item|
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

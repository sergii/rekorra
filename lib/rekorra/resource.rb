# frozen_string_literal: true

module Rekorra
  class Resource
    class << self
      def model(value = nil)
        @model_name = value.is_a?(Class) ? value.name : value.to_s if value
        @model_name
      end

      def model_class
        raise ConfigurationError, "Resource model missing for #{name}" if model.nil? || model.empty?
        model.constantize
      end

      def title(value = nil)
        @title = value if value
        @title || model_class.model_name.human.pluralize
      end

      def search_by(*names)
        @search_columns = names.map(&:to_sym) unless names.empty?
        @search_columns || []
      end

      def index(&block)
        @index = Section.new.tap { |section| section.instance_eval(&block) } if block
        @index || Section.new
      end

      def show(&block)
        @show = Section.new.tap { |section| section.instance_eval(&block) } if block
        @show || Section.new
      end

      def form(&block)
        @form = Section.new.tap { |section| section.instance_eval(&block) } if block
        @form || Section.new
      end

      def findings(&block)
        @findings = Findings::Definition.new.tap { |definition| definition.instance_eval(&block) } if block
        @findings
      end

      def jobs(&block)
        @jobs = Jobs::Definition.new.tap { |definition| definition.instance_eval(&block) } if block
        @jobs
      end

      def activity(&block)
        @activity = Activity::Definition.new.tap { |definition| definition.instance_eval(&block) } if block
        @activity
      end

      def context(&block)
        @context = Context::Section.new.tap { |section| section.instance_eval(&block) } if block
        @context || Context::Section.new
      end

      def external_link(name, label:, provider:, authorize:, **options)
        @external_links ||= []
        @external_links << ExternalLink.new(name, label: label, provider: provider,
          authorize: authorize, **options)
      end

      def external_links
        @external_links || []
      end

      # Policies are centralized per column so Index, Show, forms, search,
      # sorting and filtering share the same field-level access rules.
      def field_policy(column, read: nil, write: nil)
        @field_policies ||= {}
        name = column.to_s
        unless name.match?(/\A[a-z][a-z0-9_]*\z/) && !@field_policies.key?(name)
          raise ConfigurationError, "Invalid or duplicate field policy: #{name}"
        end
        policies = { read: read, write: write }
        policies.each do |operation, policy|
          next if policy.nil?
          unless policy.is_a?(Symbol) && policy.to_s.end_with?("?")
            raise ConfigurationError, "#{operation} policy must be a predicate symbol"
          end
        end
        @field_policies[name] = policies.freeze
      end

      def field_policies
        @field_policies || {}
      end

      def policy_for(column, operation)
        field_policies.dig(column.to_s, operation)
      end

      def permitted_fields
        form.fields.map(&:name).select { |name| model_class.column_names.include?(name.to_s) }
      end

      def validate!
        field_policies.each_key do |column|
          unless model_class.column_names.include?(column)
            raise ConfigurationError, "Unknown field policy column: #{column}"
          end
        end
        index.validate_index!(model_class)
        findings&.validate!
        jobs&.validate!
        activity&.validate!(model_class)
        (index.fields + show.fields + form.fields).each do |field|
          next if model_class.column_names.include?(field.name.to_s)
          next if model_class.reflect_on_association(field.name)

          raise ConfigurationError, "Unknown field #{field.name} on #{model_class}"
        end
        show.associations.each do |name|
          raise ConfigurationError, "Unknown association #{name}" unless model_class.reflect_on_association(name)
        end
      end
    end
  end
end

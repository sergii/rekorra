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

      def permitted_fields
        form.fields.map(&:name).select { |name| model_class.column_names.include?(name.to_s) }
      end

      def validate!
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

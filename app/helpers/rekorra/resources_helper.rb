# frozen_string_literal: true

module Rekorra
  module ResourcesHelper
    def rekorra_field_value(record, field)
      value = record.public_send(field.name)
      return field.renderer.call(value, record: record, field: field) if field.renderer.respond_to?(:call)

      reflection = record.class.reflect_on_association(field.name)
      if reflection&.belongs_to?
        id = record.public_send(reflection.foreign_key)
        return "None" if id.nil?
        related = @visible_associations.fetch(field.name, {})[id.to_s]
        return "Restricted" unless related

        text = related.respond_to?(:name) ? related.name : "##{related.to_param}"
        slug = Rekorra.slug_for(related.class)
        return slug ? link_to(text, record_path(slug: slug, id: related.to_param)) : text
      end

      return "None" if value.nil?
      case field.type
      when :money then number_to_currency(value.to_i / 100.0, unit: "$")
      when :badge then content_tag(:span, value.to_s, class: "rk-badge")
      when :datetime then l(value, format: :long)
      else value.to_s
      end
    end
  end
end

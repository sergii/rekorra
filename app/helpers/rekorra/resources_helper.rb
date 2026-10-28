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

    # Clicking a sortable table header always starts at the first result page.
    # Cursor/page are deliberately absent: the new sort invalidates both.
    def rekorra_index_sort_params(query, field_name)
      name = field_name.to_s
      unless query.sort_columns.include?(name)
        raise ConfigurationError, "Index column is not sortable"
      end

      direction = query.sort == name && query.direction == "asc" ? "desc" : "asc"
      query.navigation_params.merge(sort: name, direction: direction)
    end

    def rekorra_index_without_filter(query, key)
      remaining = query.filter_values.except(key.to_s)
      params = query.navigation_params.except(:filters)
      params[:filters] = remaining unless remaining.empty?
      params
    end

    def rekorra_index_filter_label(index, key)
      name = key.to_s
      filter = index.filters.find do |entry|
        name == entry.name || name.start_with?("#{entry.name}_")
      end
      return name.humanize unless filter

      suffix = name.delete_prefix(filter.name).delete_prefix("_")
      suffix.empty? ? filter.label : "#{filter.label} #{suffix}"
    end
end

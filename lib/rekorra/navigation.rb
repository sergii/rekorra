# frozen_string_literal: true

module Rekorra
  # Build a presentation-only tree from explicitly registered resources.
  # Authorization is evaluated before metadata is exposed.
  module Navigation
    module_function

    def build(resources:, strategy:, resolve:, allowed:)
      unless %i[namespace alphabetical].include?(strategy)
        raise ConfigurationError, "Unknown navigation strategy: #{strategy}"
      end

      root = { groups: {}, items: [] }
      resources.each_key do |slug|
        resource = resolve.call(slug)
        model = resource.model_class
        next unless allowed.call(model, :index?)
        metadata = resource.navigation
        next if metadata[:hidden]

        path = if strategy == :alphabetical
          []
        elsif metadata[:group]
          Array(metadata[:group]).map(&:to_s)
        else
          model.name.split("::")[0...-1]
        end
        path = ["General"] if path.empty? && strategy == :namespace
        node = path.reduce(root) do |parent, label|
          parent[:groups][label] ||= { groups: {}, items: [] }
        end
        node[:items] << { slug: slug, label: resource.title, position: metadata[:position] }
      end
      sort_tree(root)
    end

    def sort_tree(node)
      {
        groups: node[:groups].sort_by { |label, _| [label.downcase, label] }.to_h.transform_values { |child| sort_tree(child) },
        items: node[:items].sort_by { |item| [item[:position] || Float::INFINITY, item[:label].downcase, item[:slug]] }
      }
    end
  end
end

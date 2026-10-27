# frozen_string_literal: true

module Rekorra
  Field = Struct.new(:name, :type, :options, keyword_init: true) do
    def renderer
      options[:renderer]
    end

    def label
      options.fetch(:label) { name.to_s.humanize }
    end
  end
end

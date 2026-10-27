# frozen_string_literal: true

module Rekorra
  class HomeController < ApplicationController
    def index
      authorize!(nil, :access?)
      @resources = Rekorra.configuration.resources.filter_map do |slug, _name|
        resource = Rekorra.resource_for(slug)
        [slug, resource] if allowed?(resource.model_class, :index?)
      end
    end
  end
end

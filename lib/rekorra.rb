# frozen_string_literal: true

require "rails/engine"
require "active_support/core_ext/string/inflections"
require_relative "rekorra/version"
require_relative "rekorra/errors"
require_relative "rekorra/configuration"
require_relative "rekorra/authorization/adapters/pundit"
require_relative "rekorra/field"
require_relative "rekorra/index/filter"
require_relative "rekorra/index/pagination"
require_relative "rekorra/index/cursor"
require_relative "rekorra/index/keyset"
require_relative "rekorra/section"
require_relative "rekorra/external_link"
require_relative "rekorra/findings/definition"
require_relative "rekorra/findings/finding"
require_relative "rekorra/findings/registry"
require_relative "rekorra/findings/resolver"
require_relative "rekorra/jobs/definition"
require_relative "rekorra/jobs/item"
require_relative "rekorra/jobs/registry"
require_relative "rekorra/jobs/resolver"
require_relative "rekorra/jobs/adapters/solid_queue"
require_relative "rekorra/jobs/adapters/sidekiq"
require_relative "rekorra/activity/definition"
require_relative "rekorra/activity/event"
require_relative "rekorra/activity/registry"
require_relative "rekorra/activity/resolver"
require_relative "rekorra/activity/adapters/paper_trail"
require_relative "rekorra/context_ref"
require_relative "rekorra/external_ref"
require_relative "rekorra/context/section"
require_relative "rekorra/resource"
require_relative "rekorra/context/resolver"
require_relative "rekorra/external_links/resolver"
require_relative "rekorra/query"
require_relative "rekorra/visible_associations"

module Rekorra
  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield configuration
    end

    def resource_for(slug)
      class_name = configuration.resources[slug.to_s]
      raise UnknownResource, "Resource not registered" unless class_name

      klass = class_name.constantize
      raise ConfigurationError, "Not a Rekorra::Resource: #{class_name}" unless klass < Resource
      klass
    end

    def slug_for(model)
      configuration.resources.find do |_slug, class_name|
        class_name.constantize.model_class == model
      end&.first
    end
  end
end

require_relative "rekorra/engine"

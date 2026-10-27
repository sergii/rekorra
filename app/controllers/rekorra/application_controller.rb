# frozen_string_literal: true

module Rekorra
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout "rekorra/application"
    before_action :authenticate_actor!

    helper_method :rekorra_actor, :rekorra_theme, :allowed?, :scoped_for
    rescue_from NotAuthenticated, with: :not_authenticated
    rescue_from NotAuthorized, with: :not_authorized
    rescue_from UnknownResource, with: :unknown_resource
    rescue_from ActiveRecord::RecordNotFound, with: :unknown_resource

    private

    def authenticate_actor!
      Rekorra.configuration.ready!
      @rekorra_actor = Rekorra.configuration.authenticate_with.call(self)
      raise NotAuthenticated unless @rekorra_actor
    end

    def rekorra_actor
      @rekorra_actor
    end

    def allowed?(subject, action)
      Rekorra.configuration.authorize_with.call(rekorra_actor, subject, action) == true
    end

    def authorize!(subject, action)
      raise NotAuthorized unless allowed?(subject, action)
    end

    def scoped_for(model)
      relation = Rekorra.configuration.scope_with.call(rekorra_actor, model)
      unless relation.is_a?(ActiveRecord::Relation) && relation.klass == model
        raise ConfigurationError, "Scope adapter must return ActiveRecord::Relation for #{model}"
      end
      relation
    end

    def rekorra_theme
      value = cookies[:rekorra_theme]
      %w[auto light dark].include?(value) ? value : "auto"
    end

    def not_authenticated
      render plain: "Authentication required", status: :unauthorized
    end

    def not_authorized
      render plain: "Access denied", status: :forbidden
    end

    def unknown_resource
      render plain: "Record not found", status: :not_found
    end
  end
end

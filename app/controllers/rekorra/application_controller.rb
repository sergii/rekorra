# frozen_string_literal: true

module Rekorra
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception
    layout "rekorra/application"

    before_action :authenticate_actor!
    helper_method :rekorra_actor, :rekorra_theme

    rescue_from NotAuthenticated, with: :not_authenticated
    rescue_from NotAuthorized, with: :not_authorized

    private

    def authenticate_actor!
      Rekorra.configuration.ready!
      @rekorra_actor = Rekorra.configuration.authenticate_with.call(self)
      raise NotAuthenticated unless @rekorra_actor
    end

    def rekorra_actor
      @rekorra_actor
    end

    def authorize!(subject, action)
      raise NotAuthorized unless Rekorra.configuration.authorize_with.call(rekorra_actor, subject, action) == true
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
  end
end

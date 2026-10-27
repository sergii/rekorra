# frozen_string_literal: true

module Rekorra
  class ThemesController < ApplicationController
    def update
      authorize!(nil, :access?)
      theme = params[:theme].to_s
      cookies.permanent[:rekorra_theme] = { value: theme, same_site: :lax } if %w[auto light dark].include?(theme)
      redirect_back fallback_location: root_path
    end
  end
end

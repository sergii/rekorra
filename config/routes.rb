# frozen_string_literal: true

Rekorra::Engine.routes.draw do
  root to: "home#index"
  post "/theme", to: "themes#update", as: :theme
end

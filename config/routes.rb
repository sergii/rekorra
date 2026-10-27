# frozen_string_literal: true

Rekorra::Engine.routes.draw do
  root to: "home#index"
  post "/theme", to: "themes#update", as: :theme
  get "/resources/:slug", to: "resources#index", as: :records
  get "/resources/:slug/new", to: "resources#new", as: :new_record
  post "/resources/:slug", to: "resources#create"
  get "/resources/:slug/:id", to: "resources#show", as: :record
  get "/resources/:slug/:id/edit", to: "resources#edit", as: :edit_record
  patch "/resources/:slug/:id", to: "resources#update"
  delete "/resources/:slug/:id", to: "resources#destroy"
end

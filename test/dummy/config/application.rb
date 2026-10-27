# frozen_string_literal: true

require_relative "boot"
require "rails/all"
require "rekorra"

Bundler.require(*Rails.groups)

module RekorraDemo
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.load_defaults 8.0
    config.session_store :cookie_store, key: "_rekorra_demo_session", same_site: :lax
    config.eager_load = false
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE", "development-and-test-only-" * 4) unless Rails.env.production?
  end
end

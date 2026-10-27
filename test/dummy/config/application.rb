# frozen_string_literal: true

require_relative "boot"
require "rails/all"
require "rekorra"

Bundler.require(*Rails.groups)

module RekorraDemo
  class Application < Rails::Application
    config.load_defaults 8.0
    config.eager_load = false
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE", "development-and-test-only-" * 4) unless Rails.env.production?
  end
end

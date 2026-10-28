# frozen_string_literal: true

source "https://rubygems.org"
gemspec

# Keep Rails selection explicit in CI; do not pin the published engine to this.
if ENV["REKORRA_RAILS_SERIES"]
  series = ENV.fetch("REKORRA_RAILS_SERIES")
  raise "Unsupported Rails compatibility target" unless %w[8.0 8.1].include?(series)
  gem "rails", "~> #{series}.0"
else
  gem "rails", ">= 8.0", "< 9.0"
end
gem "sqlite3", ">= 2.1", "< 3.0"
gem "propshaft", ">= 1.1", "< 3.0"
gem "puma", ">= 6.0", "< 8.0"

# Optional real Hotwire browser host, never a published engine dependency.
if ENV["REKORRA_HOTWIRE_BROWSER"] == "1"
  gem "importmap-rails", "~> 2.0"
  gem "turbo-rails", "~> 2.0"
  gem "stimulus-rails", "~> 1.3"
end

# Demo-host integration only; the published Rekorra gem does not require PaperTrail.
gem "paper_trail", "~> 17.0"

# Demo host only. The Rekorra gem has no Solid Queue dependency.
gem "solid_queue", "~> 1.6.0"

# Optional Redis-backed Sidekiq backend used only by the demo integration.
gem "sidekiq", "~> 7.3"
# Sidekiq 7.3 uses the connection_pool 2.x scheduler API; 3.0 breaks it.
# This is test-host-only, not a published Rekorra dependency.
gem "connection_pool", ">= 2.5", "< 3.0"

# Browser acceptance only. Neither gem is a Rekorra runtime dependency.
gem "capybara", "~> 3.40", group: :test
gem "selenium-webdriver", "~> 4.30", group: :test

# Optional Pundit adapter contract and policy scopes; test-host only.
gem "pundit", "~> 2.5", group: :test

# PostgreSQL compatibility job only. This remains a test-host dependency,
# never a required runtime dependency of the Rekorra Engine.
gem "pg", "~> 1.5", group: :test if ENV["REKORRA_TEST_DATABASE_URL"]&.start_with?("postgres")

# MySQL compatibility host only. The published gem does not depend on mysql2.
gem "mysql2", "~> 0.5.6", group: :test if ENV["REKORRA_TEST_DATABASE_URL"]&.start_with?("mysql2:")

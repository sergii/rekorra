# frozen_string_literal: true

source "https://rubygems.org"
gemspec

gem "rails", ">= 8.0", "< 9.0"
gem "sqlite3", ">= 2.1", "< 3.0"
gem "propshaft", ">= 1.1", "< 3.0"
gem "puma", ">= 6.0", "< 8.0"

# Demo-host integration only; the published Rekorra gem does not require PaperTrail.
gem "paper_trail", "~> 17.0"

# Demo host only. The Rekorra gem has no Solid Queue dependency.
gem "solid_queue", "~> 1.6.0"

# Optional Redis-backed Sidekiq backend used only by the demo integration.
gem "sidekiq", "~> 7.3"

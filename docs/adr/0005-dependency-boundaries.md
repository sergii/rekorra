# ADR 0005 - Dependency boundaries

Status: Accepted for prototype

- Host Ruby >= 3.2; initial Rails range >= 8.0, < 9.0.
- Core runtime dependencies: railties, actionpack, activerecord, activesupport.
- No required Node/npm/yarn, React, Vue, WASM, Turbo, or Stimulus.
- Server-rendered Rails HTML and packaged CSS through Propshaft.
- SQLite, Puma, Propshaft, Rails meta gem belong to the demo Gemfile only.
- PaperTrail, Solid Queue, Sidekiq, ActiveStorage, observability vendors remain optional adapters.
- CI must explicitly test Rails 8.0 as well as 8.1 before declaring compatibility for the whole range.
- Sprockets and coexistence with host Turbo/Stimulus remain future test gates.

# Rekorra

Rails-native, modular administration and back-office engine.

**Status:** Early technical prototype. Do not use for sensitive production data.

## Layout

- `lib/rekorra` and `app/`: packaged Rails Engine gem
- `test/dummy`: real Rails host with Organization, Customer, Order and Payment
- `test/`: integration tests for each vertical slice
- `docs/adr/`: design decisions
- `docs/steps/`: granular development history and validation status

## Try the demo

Ruby 3.2+, Rails 8.x and Bundler are required.

```sh
bundle install
cd test/dummy
bundle exec rails db:migrate db:seed
REKORRA_DEMO_PASSWORD=local-test-password bundle exec rails server
```

Open `http://localhost:3000/backoffice` and use HTTP Basic username `acme` (or `globex`) with password `local-test-password`. Records are organization-scoped. Never deploy the demo credentials in production.

The demo does not have custom views. The engine renders the resources.

## Test

From the root:

```sh
RAILS_ENV=test bundle exec ruby test/dummy/bin/rails db:migrate
bundle exec rake test
```

The host app needs no npm/yarn, React/Vue or frontend compilation. Rekorra ships HTML and CSS. Stimulus/Turbo support is deliberately deferred until baseline HTML behavior is verified.

## Configure a host application

```ruby
# config/routes.rb
mount Rekorra::Engine => "/backoffice"
```

```ruby
# config/initializers/rekorra.rb
Rekorra.configure do |config|
  config.authenticate_with = ->(controller) { controller.current_user }
  config.authorize_with = ->(actor, subject, action) { MyPolicy.allowed?(actor, subject, action) }
  config.scope_with = ->(actor, model) { MyPolicy.scope(actor, model) }
  config.resource :orders, "OrderResource"
end
```

Security hooks are **required**. Authentication alone never grants data access; all read/write paths depend on scoped relations and authorization. These snippets illustrate contracts, not a complete production policy.

## Generic Resource Index v2 (Step 0005)

All ordinary model pages can configure static typed filters, sort/search columns and bounded pagination:

```ruby
index do
  field :name
  field :email
  field :status

  search_by :name, :email
  filter :status, type: :select, options: %w[active suspended invited]
  filter :created_at, type: :date_range
  sort_by :name, :email, :created_at

  pagination do
    strategy :offset
    per_page 25
    max_per_page 100
  end
end
```

No paginator gem is mandatory. The host-supplied `scope_with` must enforce row visibility before pagination; Rekorra applies another per-record `:show?` check when rendering. Large offsets, full-text search and keyset/cursor strategies remain separate follow-up work.

To test a large index, from `test/dummy`, run `bundle exec rails db:prepare db:seed` and `bundle exec rake 'demo:seed_users[50000]'`, then open `/backoffice/resources/users`.

See [Step 0005](docs/steps/0005-resource-index-v2.md).

## Findings (Step 0004)

Host-owned read-only rules can declare a business mismatch without requiring new tables or a background process:

```ruby
findings do
  rule :paid_but_pending
  authorize :view_findings?
  limit 10
end
```

Configure `config.finding_rules.register :paid_but_pending, "PaidButPending"` (resolved lazily after Rails autoloading), with `PaidButPending#evaluate(record:)` returning a `Rekorra::Findings::Finding` or nil. Findings are recomputed per authorized Show request, not persisted, and never automatically fix a record.

See [Step 0004](docs/steps/0004-findings.md).

## Sidekiq backend (Step 0003.1)

The demo also has a `:sidekiq_orders` resource to prove a second backend can be used with the same Jobs contract. The host installs Sidekiq and configures:

```ruby
config.job_adapters.register :sidekiq,
  Rekorra::Jobs::Adapters::Sidekiq.new(
    links: ->(order) { order.demo_job_links.where(provider: "sidekiq") }
  )
```

Sidekiq Redis must be running for this optional view; its API is eventually consistent and the adapter scans a bounded subset of queues. Missing jobs mean **unavailable**, not completed. This is not a production-grade job lifecycle audit.

See [Step 0003.1](docs/steps/0003-1-sidekiq.md).

## Background Jobs (Step 0003)

The demo host uses Solid Queue with explicit `Order -> DemoJobLink -> ActiveJob ID` correlations. The engine renders provider-neutral job metadata and requires a distinct permission.

```ruby
jobs do
  source :solid_queue
  authorize :view_jobs?
  limit 10
end
```

Registered adapter in the host initializer:

```ruby
config.job_adapters.register :solid_queue,
  Rekorra::Jobs::Adapters::SolidQueue.new(links: ->(order) { order.demo_job_links })
```

This is read-only and deliberately never inspects serialized job arguments or exposes raw exception text. Solid Queue is only a demo dependency, not a published Rekorra requirement.

To run the demo, prepare both primary and queue SQLite databases with `RAILS_ENV=development bundle exec rails db:prepare` from `test/dummy`. Run a Solid Queue worker separately to process enqueued jobs; simply visiting the UI does not execute jobs.

See [Step 0003](docs/steps/0003-jobs.md).

## Activity (Step 0002)

Rekorra supports optional, policy-guarded activity history without requiring PaperTrail in the published gem. The demo host installs PaperTrail 17 and tracks Order versions.

```ruby
activity do
  source :paper_trail
  fields :number, :status, :total_cents
  authorize :view_activity?
  limit 10
end
```

Configure the host's activity registry, `activity_actor_with` and authorization callback to enable this. The host owns its version table and decides whether sensitive model attributes should be stored in its audit history.

See [Step 0002](docs/steps/0002-activity.md) for the implementation and limitations. Jira integration is deferred to [backlog](docs/backlog/jira-integration.md).

## Linked context (Step 0001.6)

A resource can declare typed context independently from external URL builders:

```ruby
context do
  record :customer, resource: :customers, id: ->(order) { order.customer_id }
  external :issue, provider: :jira, instance: "example.atlassian.net",
    kind: :issue, id: ->(order) { order.support_issue_id },
    display_key: ->(order) { order.support_issue_key }, authorize: :view_issues?
end
```

The host configures `context_application`, `context_environment` and
`context_tenant_with` (a callable returning the current actor's tenant).
Internal targets must be registered resources and pass scoped relation plus
`:show?` authorization. External references are metadata, not working Jira links,
and use their own policies. No provider network calls or extra gem tables.

## External links (Step 0001.5)

A resource can expose authorized, provider-specific deep links without fetching external data:

```ruby
# Host initializer: explicitly allow external domains.
config.external_link_allowed_hosts = %w[github.com service.sumologic.com]
config.external_services[:sumo_logic] = {
  base_url: "https://service.sumologic.com"
}

# OrderResource:
external_link :logs, label: "See logs", provider: :sumo_logic,
  query: ->(order) { "order_id=#{Integer(order.id)}" },
  authorize: :view_logs?
```

The host must implement `:view_logs?` authorization in its `authorize_with` callback. External links never bypass the provider's own session, SSO, or RBAC. `https` + configured allowed hosts are mandatory. Each provider's URL uses encoded scalar query parameters.

Read [Step 0001.5](docs/steps/0001-5-external-links.md) for evidence and remaining checks. Provider-neutral references and Jira integration are planned next, not implemented.


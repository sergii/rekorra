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
bundle exec rails db:prepare db:seed
REKORRA_DEMO_PASSWORD=local-test-password bundle exec rails server
```

Open `http://localhost:3000/backoffice` and use HTTP Basic username `acme` (or `globex`) with password `local-test-password`. Records are organization-scoped. Never deploy the demo credentials in production.

The demo does not have custom views. The engine renders the resources.

## Compatibility matrix

CI runs Rails 8.0 and 8.1 on Ruby 3.3 and 3.4, plus Chrome browser acceptance and a separate installed-gem Rails host smoke. PostgreSQL 16 and MySQL 8.4 have each passed dedicated full integration CI jobs as the host's primary database. Solid Queue stays on SQLite. This does not establish production throughput or release readiness. These checks do not yet establish production readiness. See [Step 0008.0](docs/steps/0008-production-readiness.md), [Step 0008.1](docs/steps/0008-1-postgresql.md) and [Step 0008.2](docs/steps/0008-2-mysql.md), plus [Step 0008.3](docs/steps/0008-3-asset-hosts.md).

## Test

Worker E2E CI has a dedicated single-worker SQLite queue fixture to avoid concurrent metadata writes, and the demo/test host constrains connection_pool for Sidekiq 7.3 compatibility. These are **not** production throughput defaults. See [Step 0008.6](docs/steps/0008-6-worker-reliability.md).


From the root:

```sh
RAILS_ENV=test bundle exec ruby test/dummy/bin/rails db:prepare
bundle exec rake test
```

Real Chrome acceptance is a separate CI job (Chrome and Redis required for local runs):

    RAILS_ENV=test REDIS_URL=redis://127.0.0.1:6379/12 bundle exec ruby -Itest test/browser/resource_index_browser.rb

GitHub Actions saves screenshots under its **rekorra-browser-acceptance** artifact. See [Step 0005.3](docs/steps/0005-3-browser-acceptance.md). Human visual and screen-reader QA are not yet complete.

The host app needs no npm/yarn, React/Vue or frontend compilation. Rekorra ships HTML, CSS and optional vanilla JavaScript. Step 0008.3 checks packaged assets in independent Propshaft/Sprockets hosts with optional Turbo/Stimulus railties. Step 0008.5 additionally verifies real Chrome Turbo Drive, form/association search, and nonce-based CSP in independently installed-gem host fixtures under both pipelines. This is not a production CDN/deployment certification. See [Step 0008.3](docs/steps/0008-3-asset-hosts.md) and [Step 0008.5](docs/steps/0008-5-production-assets.md).

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

### Optional host Importmap/Hotwire integration

A Rails host that installs and configures `importmap-rails`, `turbo-rails` and `stimulus-rails` can explicitly enable its Importmap in the Rekorra layout:

```ruby
Rekorra.configure do |config|
  config.importmap_enabled = true
end
```

The host must provide its own `config/importmap.rb` pins and `app/javascript/application.js` importing Turbo/Stimulus. Importmap remains disabled by default; no Hotwire gems are Rekorra runtime dependencies. Enabling it without installing the helper is a host configuration error. See [Step 0008.5](docs/steps/0008-5-production-assets.md).

Security hooks are **required**. Authentication alone never grants data access; all read/write paths depend on scoped relations and authorization. These snippets illustrate contracts, not a complete production policy.

## Access Audit (Step 0007)

Access Audit is distinct from PaperTrail Activity (changes/version history) and is optional per Resource.

```ruby
access_audit do
  source :active_record
  authorize :view_access_audit?
  limit 10
end
```

The host provides stable identities and owns the storage:

```ruby
config.access_audit_actor_with = ->(actor) { "user:#{actor.id}" }
config.access_audit_tenant_with = ->(actor) { actor.organization_id.to_s }
config.access_audit_adapters.register :active_record,
  Rekorra::AccessAudit::Adapters::ActiveRecord.new(model: "YourAuditEntry")
```

The demo logs authorized Order Show attempts and successful create/update/destroy, with a separately authorized, tenant-scoped read-only timeline. It stores only normalized metadata and request correlation IDs; never raw params or field values. Failed audit writes abort the operation. The demo writes to a host-owned audit table in the same DB transaction for successful mutations. Remote sinks are **not** automatically atomic. No audit gem dependency is mandatory.

See [Step 0007](docs/steps/0007-access-audit.md) and [ADR 0021](docs/adr/0021-access-audit.md).

## Advanced Resources (Step 0006)

Use one explicit field policy declaration to govern Index, Show, forms and protected POST/PATCH attributes:

\`\`\`ruby
class OrderResource < Rekorra::Resource
  model "Order"
  field_policy :total_cents, read: :view_total_cents?, write: :edit_total_cents?
end
\`\`\`

The existing host \`authorize_with\` adapter evaluates these predicates. Forbidden columns disappear from Index/Show/form controls, cannot be sorted/filtered by unauthorized actors and are rejected if forged in mutation parameters. Host SQL scoping and the policies of separate Activity/Findings integrations remain essential.

Belongs-to form fields now offer a native GET search over the host's tenant-scoped relation, returning at most 50 matching records and pinning the previously selected value. Optional vanilla JavaScript now fetches scoped GET lookup results **without losing unsaved form values or the selected relation**. Without JS, native GET lookup still reloads the form and discards drafts. See [Step 0006.1](docs/steps/0006-1-association-picker.md).

The optional [Pundit bridge](docs/steps/0006-2-pundit-adapter.md) provides separate authorization and SQL-scope adapters without adding a mandatory gem dependency.

Rails enum forms support `field :state, as: :enum`, derived from host model `defined_enums` with POST/PATCH validation. See [Step 0006.3](docs/steps/0006-3-enum-fields.md).

Native forms derive checkbox, number, date, datetime-local and text controls from host ActiveRecord types, with server-side structured-value checks before attribute assignment. See [Step 0006.4](docs/steps/0006-4-native-typed-fields.md).

See [Step 0006](docs/steps/0006-advanced-resources.md).

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

For large, frequently updated ordinary indexes, an alternative is now available:

```ruby
index do
  field :name
  field :email
  sort_by :name, :email

  pagination do
    strategy :keyset
    per_page 25
    max_per_page 100
  end
end
```

The host also configures a stable, authorization-relevant `index_cursor_context_with` callback. The encrypted one-hour cursor binds the tenant/actor, SQL scope, resource, search, filters, sort and page size. The demo provides an alternative `/backoffice/resources/cursor_users` page over the same User model; ordinary `/users` keeps offset pagination. Keyset requires explicit NOT NULL sortable columns.

No paginator gem is mandatory. The host-supplied `scope_with` must enforce row visibility before pagination; Rekorra applies another per-record `:show?` check when rendering. Large offsets and full-text search adapters remain separate follow-up work. See [Step 0005.1](docs/steps/0005-1-keyset-pagination.md) for cursor constraints.

To test a large index, from `test/dummy`, run `bundle exec rails db:prepare db:seed` and `bundle exec rake 'demo:seed_users[50000]'`, then open `/backoffice/resources/users`.

See [Step 0005](docs/steps/0005-resource-index-v2.md).

### Resource Index UX (Step 0005.2)

Ordinary model tables now provide clickable sortable headings, native collapsible filter controls, removable validated filter chips, responsive rows and full-page GET navigation. Sorting drops the old page or keyset cursor, while preserving normalized search and filters. A tiny packaged vanilla JS asset optionally shows a best-effort loading indicator. HTML forms, links and pagination all work without JavaScript.

See [Step 0005.2](docs/steps/0005-2-resource-index-ux.md).

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

## Real worker process acceptance (Step 0008.4)

An independent CI job starts real Solid Queue and Sidekiq worker subprocesses against persisted SQLite and Redis, then verifies actual domain effects and tenant-scoped Jobs UI output. It does not use perform_now or fake completion timestamps. Successful Sidekiq jobs remain Unavailable once Redis forgets the JID, rather than being treated as confirmed Finished. See [Step 0008.4](docs/steps/0008-4-real-workers.md).

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


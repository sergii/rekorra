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


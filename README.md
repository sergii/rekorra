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

Read [step 0001](docs/steps/0001-first-associations.md) for implementation status.

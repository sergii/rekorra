# Testing and release gates

1. **Contract:** configuration, DSL validation, custom renderer.
2. **Integration:** real mounted Rails host, migration, CRUD, CSRF, scoped read/write, related records.
3. **Query:** N+1 regression, allowed search/sort, bounded pagination.
4. **Packaging:** gem install, Propshaft fingerprinted CSS, host without a JS build.
5. **External Links:** provider URL/encoding contracts, host allowlist, link-specific authorization, no credential forwarding, cross-tenant rejection.
6. **Context References:** typed identity validation and immutability, tenant-scoped internal target resolution, separately authorized external references, missing ID behavior.
7. **Activity:** versions and history, actor attribution, separate policy, whitelisted changes, HTML escaping, bounded query count and length.
8. **Browser** (pending): narrow/mobile/tablet/desktop, light/dark/auto, keyboard accessibility, JavaScript disabled.
9. **Compatibility** (pending): Rails 8.0 vs 8.1; Ruby 3.2/3.3/3.4; Sprockets; host with existing Turbo and Stimulus.

## Run

```sh
bundle install
(cd test/dummy && RAILS_ENV=test bundle exec rails db:migrate)
bundle exec rake test
```

A green CI run is necessary but not sufficient for a production-ready label. Keep unchecked gates in `docs/steps`.

10. **Jobs:** real backend enqueue, scoped record mapping, forbidden policy, safe errors, missing/finished status and adapter interchangeability.

11. **Resource Index v2:** signed-off column allowlists, typed filters, SQL scope + page-size bounds, stable ordering, URL navigation, wildcard escaping and 50,000-row read test.

12. **Resource Index UX:** sortable headings, normalized GET state, chip removal, empty Index headers, native filter disclosure, packaged progressive assets and offset/keyset regression.

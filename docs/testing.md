# Testing and release gates

1. **Contract:** configuration, DSL validation, custom renderer.
2. **Integration:** real mounted Rails host, migration, CRUD, CSRF, scoped read/write, related records.
3. **Query:** N+1 regression, allowed search/sort, bounded pagination.
4. **Packaging:** gem install, Propshaft fingerprinted CSS, host without a JS build.
5. **External Links:** provider URL/encoding contracts, host allowlist, link-specific authorization, no credential forwarding, cross-tenant rejection.
6. **Context References:** typed identity validation and immutability, tenant-scoped internal target resolution, separately authorized external references, missing ID behavior.
7. **Activity:** versions and history, actor attribution, separate policy, whitelisted changes, HTML escaping, bounded query count and length.
8. **Browser** (automated Chrome partially verified): desktop at 1280 px, phones at 390/320 px, keyboard Enter, JavaScript-disabled fallback and keyset/offset navigation. Manual phone, screen-reader, contrast, zoom and visual review remain pending.
9. **Compatibility** (Step 0008.0): Rails 8.0/8.1 × Ruby 3.3/3.4 and an installed-gem smoke. Ruby 3.2, Sprockets and Turbo/Stimulus still require separate gates. PostgreSQL is covered by Step 0008.1. MySQL 8.4 passed the Step 0008.2 real-host CI integration gate (PR #20); production query plans and benchmark gates remain open.

## Run

```sh
bundle install
(cd test/dummy && RAILS_ENV=test bundle exec rails db:prepare)
bundle exec rake test
```

A green CI run is necessary but not sufficient for a production-ready label. Keep unchecked gates in `docs/steps`.

10. **Jobs:** real backend enqueue, scoped record mapping, forbidden policy, safe errors, missing/finished status and adapter interchangeability.

11. **Resource Index v2:** signed-off column allowlists, typed filters, SQL scope + page-size bounds, stable ordering, URL navigation, wildcard escaping and 50,000-row read test.

12. **Resource Index UX:** sortable headings, normalized GET state, chip removal, empty Index headers, native filter disclosure, packaged progressive assets and offset/keyset regression.


13. **Browser CI:** real Chrome with Rails, Selenium/Capybara and screenshots. Run via the browser acceptance CI job or the command in Step 0005.3. Screenshots are a review artifact, not proof of human sign-off.

14. **Advanced Resources:** read/write field authorization, forged field rejection, protected query predicates, tenant-scoped bounded association search and current selected value pinning.

15. **Advanced Resource extensions:** real Pundit policy and scope, model-declared enum select and forged mutation, Chrome draft-safe belongs_to lookup; manual Safari/VoiceOver remains pending.

16. **Access Audit:** tenant-isolated authorized Show writes, independent timeline permission, no untrusted params, successful CRUD-only events, same-DB rollback on sink failure, alternate adapter and malformed payload rejection.

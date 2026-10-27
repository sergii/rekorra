# Step 0000 - Bootable Engine

Status: Engine boot confirmed by Step 0001 Rails 8.1 CI; browser visual checks pending.

## Demo Rails application
- `test/dummy` is a real Rails host application.
- Mounts `Rekorra::Engine` at `/backoffice`.
- Demonstrates explicit demo-only HTTP Basic configuration.

## Rekorra Engine
- Isolated namespace.
- Server-rendered root page.
- Scoped CSS packaged inside gem.
- Light/dark/auto theme selection through a POST form, no JavaScript.
- Authentication and authorization required for the root page.

## Validation
- [x] Bundle install in CI
- [x] Rails engine loads
- [x] Unauthorized request returns 401
- [x] Authorized request renders the shell
- [x] CSS is fingerprinted by Propshaft
- [x] Theme form works with cookies
- [ ] Mobile browser visual check

## Known limitations
No resource models or persistent CRUD yet; this is intentional. No security claim is made before tests run.

## Next
Introduce Customer, Order and Payment in dummy and the minimal resource DSL in the gem.

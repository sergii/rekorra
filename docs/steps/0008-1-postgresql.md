# Step 0008.1 — Real PostgreSQL test-host compatibility

Status: Feature branch; CI pending.

## Purpose

Verify that Rekorra's generic Rails Engine works against a **real PostgreSQL 16 database**, including schema migrations, scoped CRUD, security checks, filters, Activity, Findings, Access Audit and both pagination strategies. The existing SQLite/Redis and independent installed-gem gates remain unchanged.

## Implementation

- Adds an isolated PostgreSQL 16 CI service and a separate Rails 8.1 / Ruby 3.4 job, in addition to the four existing Ruby/Rails SQLite jobs.
- Demo primary database accepts a CI-only \`REKORRA_TEST_DATABASE_URL\` when supplied, otherwise uses the original SQLite database.
- The Solid Queue database stays on SQLite, since the host should be free to use independent database adapters for app and jobs.
- Installs the \`pg\` driver only in the optional compatibility test host when the PostgreSQL URL is enabled. No new Rekorra gem runtime dependency.
- Runs the **full** Ruby integration suite and asserts that the primary database connection is actually PostgreSQL (not SQLite fallback).

## Acceptance

- [ ] PostgreSQL 16 CI service boots and demo migrations succeed
- [ ] Full Ruby tests pass with PostgreSQL primary
- [ ] Tenant scoping, field authorization and forged form mutations still reject leaks
- [ ] Ordinary Index offset pagination, keyset cursor and type-based filters pass
- [ ] Postgres PaperTrail JSON versioning, Access Audit, Solid Queue and Sidekiq tests pass
- [ ] Default SQLite/Rails matrix, Chrome and independent packaged gem jobs unaffected

## Open

This is a database **correctness and integration gate**, not a benchmark of index plans or throughput. Query-plan analysis for 50k+ records and real MySQL compatibility remain distinct steps. Manual physical-device and screen-reader QA also remains open.

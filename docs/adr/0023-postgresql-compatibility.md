# ADR 0023 — Real PostgreSQL compatibility with separate queue database

Status: Accepted, full CI verified for Step 0008.1.

## Context

SQLite-only integration is not sufficient evidence for a reusable admin gem used in PostgreSQL Rails hosts. Correctness of transactions, JSON-backed audit/version metadata, date-range predicates, ActiveRecord tenant scopes, keyset predicates and migrations can be adapter-specific.

## Decision

Extend test/dummy/config/database.yml to accept a CI-scoped primary database URL. By default the existing demo keeps SQLite; when REKORRA_TEST_DATABASE_URL is supplied, the Rails host uses its explicitly configured PostgreSQL database. The independent Solid Queue database remains SQLite. Add a dedicated PostgreSQL 16 service and Rails 8.1/Ruby 3.4 CI job, installing the pg Ruby driver only for this test target.

Run all Ruby integration tests under the PostgreSQL target, and verify the effective primary adapter is PostgreSQL. Keep four SQLite Rails/Ruby legs, real Chrome tests and installed .gem smoke intact. Rekorra's published gemspec does not depend on pg, mysql2, Sidekiq, Solid Queue, or a database driver.

## Acceptance evidence

[CI run 40674348352](https://github.com/sergii/rekorra/actions/runs/40674348352) passed the PostgreSQL job with 154 tests, 925 assertions, zero failures/errors/skips. The CI run also passed all existing jobs.

## Boundaries

This verifies real database integration and correctness, not throughput or EXPLAIN plans. It does not establish MySQL support, multi-database consistency of audit vs domain mutations, or production security/accessibility readiness. Mixing primary PostgreSQL and a separate SQLite queue here is a supported demo-test topology, not a claim that distributed writes are atomic. No Rails 7 support is implied.

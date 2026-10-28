# ADR 0024 - Real MySQL compatibility without a driver dependency

Status: Proposed, pending Step 0008.2 CI.

## Context

SQLite and PostgreSQL integration does not establish MySQL support. MySQL uses backtick identifier quoting and may behave differently for text collation, JSON, foreign keys, and query plans.

## Decision

Add a MySQL 8.4 + Redis GitHub Actions job on Rails 8.1 / Ruby 3.4. Switch only the demo's primary test DB via the existing REKORRA_TEST_DATABASE_URL, preserving its SQLite Solid Queue database. Fail unless ActiveRecord reports Mysql2 and run the full suite, including tenant security and 50k-row query bounds.

Keep mysql2 test-host-only, not a dependency of the published Rekorra gem. Adjust test SQL instrumentation to recognize backticks without loosening SELECT limits or security assertions.

## Boundary

A green result establishes integration correctness for this version combination, not production throughput, optimizer guarantees, cross-database atomicity, Ruby 3.2 compatibility, UI framework compatibility, or production release readiness.

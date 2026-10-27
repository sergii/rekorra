# ADR 0013 — Scoped query, typed filters and bounded offset pagination

Status: Accepted for Step 0005.

## Context

Rekorra must show ordinary model tables containing 50,000+ records without loading them all. Admin libraries must not permit request parameters to become SQL column names, raw predicates, or unrestricted query results.

## Decision

The Resource's `index do` DSL declares static filter fields, allowed sort columns and pagination bounds. Existing top-level `search_by` remains supported; an index-local declaration can override it. Each declaration is validated against ActiveRecord column metadata.

The engine starts from the **host-provided ActiveRecord::Relation** and adds allowlisted Arel predicates, ordering and `LIMIT per_page + 1 OFFSET`. The last row is a has-next sentinel. A primary-key tie-breaker guarantees stable sorting for equal values. The hard maximum is 100 records per page. No exact count is run on the default path.

GET controls preserve their state in the URL; both search and filter values are normalized before being carried to pagination links.

## Security

The host's `scope_with(actor, model)` must enforce all SQL-level row restrictions **before** filters and pagination. Per-record `show?` still applies as an additional guard, not a replacement for scoped row access. Rekorra cannot repair a row-filtering policy that exists only as a Ruby check after the query.

Only static select values, validated booleans and strictly parsed date/numeric ranges enter Arel conditions. Sortable/searchable columns are allowlisted. Invalid values cannot become SQL fragments. No `Model.all` fallback.

## Alternatives

- Mandatory Pagy or Kaminari: not now; use small built-in bounded offset pagination until multiple pagination strategies need a common abstraction.
- Always-on keyset: not yet; it complicates arbitrary multi-column sorts and direct page jumps.
- Raw SQL: unnecessary for these common predicates.
- Ransack and ActiveSearch: useful opt-in tools later for richer predicates/full-text, not needed for straightforward indexed filters.

## Tradeoffs

Large offsets and `LIKE '%substring%'` searches can be expensive even if the application only receives 25 rows. Hosts need appropriate indexes/search backends and workload-specific query optimization. Cursor pagination, query plans, policy-scoped counts and full-text adapters deserve separate tests.

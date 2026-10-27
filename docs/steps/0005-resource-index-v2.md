# Step 0005 — Generic Resource Index v2

Status: Feature branch; CI and browser verification pending.

## Goal

Make searching, filtering, sorting and pagination first-class for **ordinary model indexes** (Users, Orders, Customers), not only specialized operational pages.

## Demo host

- A read-only User model, migration, Resource and tenant scope with explicit statuses, roles, verification flag and created-at filter.
- Order model gains an ordinary index with typed status, price-range and date-range filters.
- Standard seed creates 65 Users for pagination. Optional `cd test/dummy && bundle exec rake 'demo:seed_users[50000]'` adds 50,000 Users in batches of 1,000 for large-model QA.
- No changes required to Activity, Jobs or Findings interfaces.

## Engine

- New Index DSL: `filter`, `sort_by`, `search_by` and `pagination do`.
- Strongly-typed static select, boolean, number range and date range predicates. Values are checked against configured columns and a declared allowlist.
- SQL-level filtering built with ActiveRecord and Arel, always starting with the host's `scope_with` relation.
- Configurable `per_page` with a hard maximum of 100 and 25 as the default; bounded `LIMIT per_page + 1` and `OFFSET`.
- Stable secondary primary-key order avoids arbitrary ordering of ties.
- Server-rendered GET filters and pagination links preserve selected parameters, no JavaScript and no full-table COUNT by default.

## Verification

- [ ] Ruby 3.3 / Ruby 3.4 CI green
- [ ] Users across tenants never mix, including when filters and pagination apply
- [ ] Selection, boolean, numeric and date range filters
- [ ] Unknown filter/sort/column values cannot enter SQL
- [ ] Pagination upper limit and stable secondary ordering
- [ ] Query remains bounded with 50,000 demo Users
- [ ] Search + filters preserved across Next / Previous links
- [ ] Browser and mobile visual QA

## Known limits

- Offset pagination can become slower for deep pages and may shift on concurrent inserts. Keyset / cursor strategy is future work.
- `MAX_PAGE = 10000` is a guard, not a claim that deep offsets are efficient. Host teams need database indexes for common tenant/filter/sort combinations.
- The host's `scope_with` SQL relation **must enforce row visibility** before pagination. Rekorra still performs a further per-record `:show?` check after pagination, so a row-level policy stricter than `scope_with` can produce a short page.
- Filters only target model columns; association filters, complex grouped OR queries, persisted saved searches, multi-column sorting, export and full-text indexes are future work.
- No exact count or numbered last page is promised, to avoid expensive COUNT queries.
- No new paginator gem is mandatory. Cursor pagination, an optional Pagy adapter and full-text search adapters (e.g. ActiveSearch) are backlog items.
- Rails 7 is not validated or supported by the gemspec (currently Rails >= 8.0 and < 9.0). Ruby 3.3/3.4 CI is not a full Rails-version compatibility matrix.

## Next

Step 0005.1: cursor/keyset pagination on supported stable indexed sorts, with signed cursors and tenant/filter binding; optional paginators can be evaluated behind the same contract.

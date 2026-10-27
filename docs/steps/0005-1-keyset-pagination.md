# Step 0005.1 — Secure Keyset / Cursor Pagination

Status: Feature branch; integration CI and manual browser QA pending.

## Goal

Support a second pagination strategy for ordinary model indexes (Users, Orders, etc.), preserving the Step 0005 search/filter/sort DSL and a small server-rendered Previous/Next UI. No mandatory Pagy dependency and no full table COUNT.

## Demo host

- A separate `CursorUserResource` points to the same `User` model and tenant-scoped relation as regular `UserResource`. The ordinary Users page still uses offset.
- Opt-in `index { pagination { strategy :keyset; per_page 25; max_per_page 100 } }`.
- Host configures `config.index_cursor_context_with = ->(actor) { "organization:#{actor.id}" }` (example only; production must include all authorization-relevant context).
- The existing optional `demo:seed_users[50000]` provides a large-model dataset.

## Architecture

- `Index::Keyset` uses a lexicographic cursor with the selected column and an ascending primary-key tie-breaker. The query fetches at most `per_page + 1` rows.
- Keyset navigation supports both ascending/descending sorting and both Next/Previous. For Previous the database reverses ordering before the returned rows are restored to display order.
- `Index::Cursor` encrypts and authenticates cursor contents with a Rails app-derived key (`aes-256-gcm`) and one-hour expiry. It hashes the resource name, scope SQL, host context, search, normalized filters, sort, direction and page size into its fingerprint.
- Query and view share existing filter and search mechanisms; the cursor never carries arbitrary SQL or serialized model arguments.
- Unknown/tampered/expired/wrong-context cursor returns HTTP 400, not a 500 or a fresh first page.
- When keyset is selected, `page` and SQL OFFSET are unused. The offset strategy is unchanged.

## Constraints and risk boundaries

- Keyset requires explicit `sort_by` columns which are scalar, comparable and `NOT NULL` in the database schema. `NULL` ordering and complex association-derived sorts are deliberately not supported yet.
- The host must enforce SQL-level visibility through `scope_with`; record-level `:show?` authorization is still applied **after** the limit as an extra check, which can yield short pages if it is stricter.
- The host callback must return a stable actor/tenant identity; cursors also bind the SQL scope, but neither mechanism proves a host's policy implementation is correct.
- Cursor encryption makes URLs opaque, not secret-free: the token is a temporary bearer pointer for an already authenticated, tenant-scoped list. Do not put credentials in the sort columns or query.
- No snapshot isolation: insertions/deletions and sort-key edits between requests can still alter the visible sequence.
- No total count, page numbers, jump-to-end, CSV export, composite PK, nullable sorts, or automatic database index creation.
- SQL query performance on PostgreSQL/MySQL is not benchmarked here; appropriate compound indexes remain the host's responsibility.

## Verification

- [ ] Ruby 3.3 / 3.4 CI green
- [ ] Navigates forward and backward through duplicate sort values without duplicates/skips
- [ ] ASC / DESC and primary-key cursor ordering
- [ ] Invalid/tampered/tenant-crossed/search-changed cursor fails closed with HTTP 400
- [ ] Filters and page-size preserved during navigation
- [ ] SQL queries use LIMIT without OFFSET or COUNT
- [ ] Offset Resource Index remains unchanged
- [ ] Manual mobile/table visual QA

## Next

Evaluate NULL-aware cursor ordering and long-running query performance with PostgreSQL. Then, if needed, compare the adapter contract with optional Pagy keyset integration.

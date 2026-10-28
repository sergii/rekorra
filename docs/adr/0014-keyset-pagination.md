# ADR 0014 — Encrypted, actor/scope-bound cursor pagination

Status: Accepted and verified in Step 0005.1 integration CI; manual browser QA pending.

## Context

Admin model tables can have tens of thousands of rows. Offset pagination is simple but deep offsets become expensive and live data moves between pages. A second strategy must coexist with Resource Index v2 without introducing a mandatory gem.

## Decision

Use scoped ActiveRecord and Arel with a deterministic two-term order (declared sort column plus ascending primary key). Seek using a lexicographic predicate. Reverse the comparison and ordering for Previous, then reverse the resulting page in Ruby. Limit each SQL page to at most `per_page+1` records. Do not query `COUNT(*)`.

The host opts in with `strategy :keyset` and supplies a stable `index_cursor_context_with` callback. Use AES-256-GCM with a Rails key-generator derived key, a strict purpose, expiry and a fingerprint of resource, scope SQL, host context, normalized filters, search, sort, direction and page size. Failed verification returns HTTP 400. The cursor is not a standalone authorization grant.

## Security

Only registered resources with an authorized index action and SQL-level `scope_with` relation are queried. Only whitelisted, non-null, comparable columns may be used for keyset sorting. A cursor from one actor/scope/resource/selection cannot be used for another. No user-provided SQL column or expression is accepted. `show?` remains defense-in-depth after pagination.

## Alternatives

- Pagy keyset: optional adapter later; current small implementation demonstrates the contract without mandatory dependencies.
- Unencrypted signed cursor: sufficient for integrity but exposes last sort values (e.g. user email); rejected.
- OFFSET with increasing page numbers: retained for regular resources but not keyset resources.
- Record IDs alone: cannot guarantee deterministic ordering when the selected sort column has duplicate values.

## Limits

No NULL-ordering, multi-column user sort, multiple DB adapter benchmarks or snapshot isolation. Database indexes must support the host's tenant scope and common sort/predicate pairs.

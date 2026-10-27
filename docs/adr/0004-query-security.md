# ADR 0004 - Resource queries and relation scoping

Status: Accepted (prototype)

## Decision
Every list, item lookup, related association and relationship selection starts from an adapter-provided ActiveRecord::Relation, not Model.all. Permit search only on declared text fields, sorting only on declared model columns, and bounded pagination.

## Authorization
An index policy gates the list, a show policy gates each returned item, and per-record policies gate mutations. The scope is the authoritative row-level visibility layer. Form foreign keys are checked against scoped relations.

## Caveats
This is an alpha proof, not a complete defense against all policy complexity. Row-level show rejection after pagination can produce short pages. No polymorphic associations or custom primary keys yet. Additional tests are needed for join ordering, composite keys and user-defined policies.


## Update: Step 0005 — Resource Index v2

Added validated, typed filter declarations, bounded user-selectable page size and explicit sort columns to the ordinary model Index. The SQL-level `scope_with` remains authoritative for record visibility before pagination. Per-record `show?` rejection still occurs after pagination; short pages are a documented limitation. See [ADR 0013](0013-resource-index-v2.md).

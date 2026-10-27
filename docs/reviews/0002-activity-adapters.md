# Activity Adapter Contract Review (2026-10-28)

Status: Contract verified in CI (Ruby 3.3 / 3.4); multi-source support remains out of scope.

## Verified architecture

- Resource DSL declares a named source, policy, field allowlist and limit.
- Resolver authorizes the record, finds the registered source and calls a provider-independent `events(record:, fields:, limit:)` contract.
- Providers translate data into `Activity::Event` and `Activity::Change`.
- PaperTrail-specific calls (`versions`, `changeset`, `PaperTrail.request`) live only in its adapter.
- The published gem has no runtime dependency on PaperTrail.
- A second, fake `:domain_events` adapter demonstrates interchangeability in an automated test.

## Boundary improvement

Prior to this review the registry required every adapter to provide both read `events` and write `with_actor`, which excluded otherwise valid read-only sources.

After this change:
- `events(record:, fields:, limit:)` is mandatory.
- `with_actor(actor:) { ... }` is optional.
- An adapter with `with_actor` receives the host's actor for Rekorra-initiated writes.
- If the adapter doesn't implement `with_actor`, it is responsible for event creation independently, and Rekorra does not claim to attribute writes.

## Remaining constraints (not addressed by this review)

1. **Single source per Resource:** The DSL currently exposes one `source :name`. Future domain event + PaperTrail timelines need multi-source merging, stable ordering and deduplication.
2. **Database-only fields:** `Definition#validate!` requires field names from `model.column_names`. This rejects legitimate provider-defined event fields for non-AR events.
3. **Thin event model:** `Event` contains kind, time, actor and changes but lacks source ID, event ID, correlation ID, provenance and links. Cannot merge/paginate providers reliably yet.
4. **Provider-owned allowlist implementation:** The PaperTrail adapter filters its change payload, but future adapters also need a contract/invariant test to prove they don't leak unapproved fields.
5. **No pagination or cross-source cursor:** Each provider caps one list; merging across providers requires explicit policies about ordering, sampling and access.
6. **Read auditing is distinct:** PaperTrail records changes, not every viewed record; Web Access Audit must remain separate.

## Validation criteria

- [x] Non-PaperTrail source registered and resolved through provider-neutral resolver.
- [x] Read-only provider works without `with_actor`.
- [x] Existing PaperTrail actor attribution and ACL tests remain green.
- [x] Ruby 3.3/3.4 CI passed.

Evidence: [GitHub Actions CI run 40598021894](https://github.com/sergii/rekorra/actions/runs/40598021894). 52 tests, 223 assertions, 0 failures, 0 errors, 0 skips per Ruby matrix job.

## Next architecture spike

Before implementing a second real activity gem, define a provider-neutral immutable event record and a multi-source query strategy. Add an adapter-conformance test suite so every provider must honor authorization, field allowlists, result limits, and safe rendering.

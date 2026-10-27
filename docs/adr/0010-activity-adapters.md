# ADR 0010 - Optional Activity adapters and protected timeline

Status: Accepted for Step 0002.

## Decision

Activity is an optional resource capability. Rekorra Core supplies an `Activity::Registry`, a resource-level `activity do` DSL, a resolver, and a small immutable-ish presentation model (`Event`, `Change`). An external provider supplies the events.

The first adapter uses PaperTrail through the host model's `versions` relation and `changeset`, but the published Rekorra gem has no dependency on PaperTrail.

## Authorization

The current record must pass normal scoped retrieval and `:show?` before any events are resolved. The Activity section additionally requires an explicit `:view_activity?` (or host-configured equivalent) policy. Denied checks do not invoke the adapter. Only the explicitly whitelisted field changes can be rendered.

## Actor attribution

The host supplies an `activity_actor_with` callback that returns a stable, nonempty actor identity. When create/update/destroy runs through Rekorra, the adapter temporarily sets `PaperTrail.request(whodunnit: actor)` for the write block. The host may separately configure PaperTrail for edits elsewhere in the app. The demo uses an organization slug, not a real user; production auditing must use a real actor ID.

## Storage and lifetime

Versions are owned by the host app. The demo stores `object` and `object_changes` as JSON. Host teams manage retention, redaction/`skip:`, encryption, indexing and legal requirements. Rekorra does **not** guarantee a complete access log or immutable audit trail.

## Exclusions

No full log ingestion, web view-access audit, PaperTrail version rollback, background-job collector, Jira integration or Activity-to-Investigation inference.

## Alternatives

A mandatory PaperTrail dependency, a Rekorra-owned event database, and a generic YAML event parser were rejected. Other providers may implement `events` and `with_actor` behind the registry later.

# ADR 0021 — Host-owned, fail-closed Access Audit

Status: Proposed for Step 0007; implementation CI pending.

## Decision

Access Audit is an optional Resource module with provider-neutral `Event` objects, adapter registry, separate viewing authorization and bounded read-only HTML timeline. Its write contract is `write!(event:)`; its read contract is `entries(record:, tenant_key:, limit:)`. Rekorra Core must never store request parameters, model values, serialized job arguments or raw exceptions in audit envelopes.

Tenant and actor identities must be provided explicitly by the host through `access_audit_tenant_with` and `access_audit_actor_with`. Rekorra has no stable cross-application actor concept and must not infer one from `to_s` or a cookie. Invalid or empty identities fail closed.

The first real adapter uses a host-owned ActiveRecord model with lazy constantization and a tenant+record scoped query, ordered and limited at the database. Its storage and retention are owned by the host; `rekorra.gemspec` has no audit dependency.

Write audit only for authorized Show and successful create/update/destroy. Failed validation and forbidden mutations must never claim success. In a single host DB, write the audit inside the domain transaction; sink failures abort the mutation. The viewer's policy is separate from the permission to view the underlying Order.

## Boundaries

- PaperTrail remains Activity/version history, not access auditing. Neither module relies on the other's adapter.
- The demo's organizations serve as actors, so they are tenant-level identities rather than individual people.
- Show auditing records an authorized attempt to view: later rendering errors or disconnected clients may mean the user never received the response.
- No audit for Index, API reads, denied requests, failed writes or console sessions yet.
- External sinks cannot claim cross-DB atomicity; production audit durability, immutable storage, retention, sampling/privacy and failure operations require independent design and verification.
- The audit table is not a proof of tamper resistance; the host controls DB privileges and audit retention.

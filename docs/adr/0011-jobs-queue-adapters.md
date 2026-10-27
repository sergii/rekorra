# ADR 0011 — Jobs inspection via scoped correlations and optional adapters

Status: Accepted for Step 0003 (implementation validation pending).

## Context

Job arguments may contain business identifiers, passwords or sensitive serialized objects, and queues vary significantly in persistence and status semantics. Rekorra must not scan every background job or attempt to infer tenants from raw payloads.

## Decision

- `Jobs::Registry` registers adapters satisfying `jobs(record:, limit:)`.
- `Jobs::Resolver` checks the **record-specific** policy `view_jobs?` before calling an adapter and validates bounded, normalized `Jobs::Item` output.
- `Jobs::Item` contains safe metadata only: provider-independent job ID, class, queue, state, and timestamps. No serialized arguments, secrets or raw exception text.
- The first demo uses Solid Queue with an **explicit host-owned record-to-ActiveJob-ID mapping**. Adapters receive a host-defined association already scoped to the authorized record. The host has to enforce the relationship; Core never queries `SolidQueue::Job` without the supplied IDs.
- The backend's authoritative state overrides correlation metadata; missing backend jobs are marked `unavailable`. No invented retry/attempt counts.
- Solid Queue is a demo dependency, not a Rekorra runtime dependency. The demo's queue schema belongs to the host.
- No mutation actions or automatic retries in this step.

## Security and performance

- External / cross-tenant IDs must not leak into the current record.
- Explicit permission `view_jobs?` is independent of basic `show?`.
- Query only jobs matching bounded IDs from the host association.
- Preload backend execution association statuses to avoid one query per job.
- Never render `arguments`, `error`, or raw stack traces, even for an allowed user.
- A real production adapter may use a separate queue DB; never assume the same database connection as host models.

## Scope

This prototype does not implement job execution history, failed attempt counts, retries, controls, queue administration, or generic Sidekiq compatibility. Those require separate provider contracts and specific authorization tests.

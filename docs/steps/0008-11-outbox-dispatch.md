# Step 0008.11 - Durable outbox scanner and competing leases (phase 1)

Status: PR CI pending. Host-only reference implementation, **not** published Rekorra runtime.

## Implemented

- A primary-DB, tenant-bound outbox scanner independently discovers committed intents without assuming an atomic write to the separate Solid Queue DB.
- Atomic conditional UPDATE acquires a random-token lease and increments a bounded dispatch count. A second real scanner cannot claim the same valid lease.
- SIGKILL leaves the lease durable; the next scanner reclaims only after expiration. Token fencing prevents an old process from committing delivery state after another owner has taken over. Short network timeouts remain necessary; overlapping HTTP sends are still possible across expired leases.
- A pending intent triggers delivery. An ambiguous/unknown intent attempts **GET reconciliation before any new POST**; only provider 404 allows redelivery with the **same** idempotency key.
- Bounded attempts (3) with progressive retry delays (1s/2s/4s) and terminal needs_review. No arbitrary automatic POST after reaching the cap.
- Host-only tenant/policy/reason-gated reopen of needs_review, in a transaction with a durable operator approval record. Global host-only metrics include pending, unknown, delivered, needs_review, active/expired lease counts and oldest age.
- Dispatcher constrains transport to HTTPS and configured host allowlist, except explicit localhost HTTP when Rails.env.test? with a test flag; does not accept arbitrary endpoint URLs. No secrets logged.

## Dedicated PostgreSQL CI proof

- Twelve local intents are processed by **two competing real scanner OS processes** behind a start barrier. Require both PIDs to process work and only one request per operation.
- A third scanner claims an intent and is SIGKILLed before HTTP. Lease remains, another scanner cannot claim it early, and subsequent processes reclaim after expiry with no duplicate external effect.
- Independent provider HTTP process with own PostgreSQL commits then dies before ACK. Unknown intent is reconciled by GET without another POST.
- Provider outage exercises bounded attempts and needs_review. Cross-tenant and short-reason review denied; approved operator reopen recorded, then delivery completed.

## Open gates - issue #34 remains open

- No supervised long-running scheduled service, orchestration/deployment configuration, leader election/lease-heartbeat for very long sends, distributed fairness or multi-node SLOs.
- No production provider authentication, TLS certificate/pinning operations, 429/5xx taxonomy, per-provider jitter/backoff/rate limits, signed receipts, idempotency retention agreement or real payment/email API integration.
- This bounded test has two scanner processes; existing CI separately validates two Solid Queue workers, not a combined 2-scanner × 2-worker deployment.
- No cross-system exactly-once guarantee. Operators must review unknown external effects; delivery remains at-least-once with cooperating provider dedupe.

## Runbook

Run the host-owned scanner regularly from a supervised process or scheduler and alert on needs_review, unknown age, expired lease age and backlog age. For unknown outcomes, reconcile the remote receipt first; if receipt lookup is unavailable, do not infer absence of effects. On needs_review, check remote records and provider retention before authorizing a tenant-scoped manual reopen with an audit reason. Never assume a queue job succeeded just because the remote effect did.

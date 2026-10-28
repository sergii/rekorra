# Step 0008.10 - Transactional Outbox and External Effects

Status: PR verification pending. Host-only implementation, not published Rekorra API.

## Correctness boundary

Business mutation, tenant-key idempotency ledger and outbound delivery INTENT are persisted in one primary PostgreSQL transaction. Solid Queue job enqueue and an independent provider PostgreSQL database are NOT part of that transaction. Delivery is at-least-once; an external provider must enforce a stable idempotency key and expose reconciliation. Absence of an HTTP ACK never proves absence of a side effect.

## Implementation

- `WorkerOutboxOperation.apply_once!` wraps existing `WorkerRecoveryEffect.apply_once!` and tenant-keyed `WorkerOutboxEvent.create_or_find_by!` in a single transaction. No new published gem dependency/migration.
- `WorkerOutboxDelivery` transports only a minimal JSON message and stable `Idempotency-Key` using Net::HTTP; it records `unknown` on lost acknowledgement. There is no implicit blind automatic re-send.
- A separate simulated provider **OS process** persists receipts to an **independent PostgreSQL database** and intentionally dies after commit but before replying; the receiver has unique operation keys and tracks the number of requests.
- Manual retry of a truly failed Solid Queue delivery resends the same key: two HTTP attempts produce exactly one effect in the cooperating test provider. This does **not** generalize to non-idempotent providers.
- Alternative read-only GET reconciliation queries the provider receipt after a lost ACK; it marks the outbox delivered but does not fabricate a successful Solid Queue job. A subsequent explicit retry is a local no-op.
- `WorkerOutboxHealth.snapshot` provides aggregated counts for pending/unknown/delivered and age of oldest unknown event; never expose global totals on tenant pages.

## E2E acceptance

- DB rollback removes business mutation, idempotency marker and outbox intent together.
- Same key + record returns the same outbox event and does not double-apply mutation; key collision with another same-tenant record is rejected.
- First real HTTP request commits a provider-side effect; provider SIGKILL drops the ACK, outbox stays `unknown`, Solid Queue job is `Failed`.
- After provider restart a manual queue retry produces a second HTTP request with the same stable key, one provider receipt, and delivered event.
- Second intentionally lost ACK reconciles through a provider read without another POST; queue remains Failed until explicit operator retry returns successfully without re-delivering.
- Verify two local mutations, two remote receipts, two delivered outbox events and zero unknown rows.

## Production gaps

This is a bounded local simulation. No durable outbox scanner/dispatch scheduler, lease strategy for concurrent senders, alert delivery, HTTP authentication/authorization, TLS, rate limits, provider 429/5xx policies, provider idempotency retention contract, signed receipts, dead-letter handling, multiple remote vendors, multi-tenant provider isolation proof, or production monitoring SLO. The remote provider itself is a test fixture. Never claim exactly-once delivery across a network or real payment/email providers.

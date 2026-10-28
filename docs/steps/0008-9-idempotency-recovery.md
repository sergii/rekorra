# Step 0008.9 - Idempotency and Recovery Operations

Status: PR CI pending. Test-host implementation only; not a production integration.

## Verified target behavior

- A unique primary PostgreSQL index on `(organization_id, idempotency_key)`, an order row lock, and **one transaction** commit the operation marker together with the local business effect.
- A real worker writes the business effect, is SIGKILLed while its job is claimed, and the supervisor marks the job Failed.
- Trusted host-only `WorkerRecoveryService.retry_failed!` requires: same-tenant actor and order, explicit `retry_job?` policy, approved `WorkerIdempotentRecoveryJob` class, record-owned `DemoJobLink`, actual backend Failed state, and written 12-500 character reason.
- A durable `retry_requested` decision is written before Solid Queue's official `FailedExecution#retry`, never an unlogged fire-and-forget action.
- A retry executes for real but the local effect is applied once. Another job with the same idempotency key is also a no-op. A key cannot target a different record in one tenant; another tenant owns its own namespace.
- Global host-only `WorkerRecoveryHealth.snapshot` exposes safe counts for failed jobs, aged claimed executions and registered workers, plus oldest failure age, without serialized arguments or raw errors.
- Rekorra's tenant-scoped Jobs view **remains read-only**; no general retry UI or automatic retry exists.

## Production operator runbook

1. Monitor aggregate failed queue count, worker registrations and aged claims. A long claim alone is **not** proof of failure.
2. Identify job and tenant through an authorized host-owned correlation relation, never by parsing stored job arguments.
3. Inspect *committed* side effects and external provider state before declaring a retry safe.
4. Require an explicitly authorized operator and documented approval reason; allowlist only idempotent job classes.
5. Persist the attempted decision before invoking the actual backend retry. If the backend call errors, reconcile queue state versus the logged decision, rather than blindly repeating.
6. Confirm new queue state and business invariants. Escalate unresolved/unknown effects for manual repair.

## Important boundaries

This is a **host-owned example**, not published API. The unique key covers only a local business transaction in the primary database. It cannot make external APIs, email, payments or a separate queue database exactly-once. Multi-operator concurrent approvals, real alert delivery, retention policy for keys, transactional outbox and separate recovery audit authorization remain open gates. No new Rekorra runtime dependencies.

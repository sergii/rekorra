# Step 0003.1 — Sidekiq Jobs adapter

Status: Implemented in feature branch; CI pending.

## Demo Rails app

- Adds Sidekiq 7.3 in demo Gemfile, a real `SidekiqOrderReceiptWorker`, and `SidekiqOrderResource` as an alternate view over scoped Orders.
- `DemoJobLink` now carries `provider` and `queue_name` to prevent Solid Queue and Sidekiq correlations from mixing.
- Sidekiq links are an explicit record-owned association; the adapter does not inspect serialized job arguments or infer tenant IDs.
- Redis is supplied in GitHub Actions, but the demo's Sidekiq resource requires a reachable Redis instance to inspect jobs. The normal Order page remains Solid Queue-backed.

## Rekorra

- `Rekorra::Jobs::Adapters::Sidekiq` implements the same `jobs(record:, limit:)` interface as Solid Queue.
- Reads only linked job JIDs and configured queue names. Uses bounded Sidekiq API traversal for queue, scheduled, retry and dead states.
- Does not present raw arguments, exception payloads, stack traces or discovered unlinked job identifiers.
- A missing JID is `unavailable`, **not** assumed completed. Sidekiq's default Redis state does not prove successful completion.
- Does not expose retries, cancellation, execution or mutations.

## Acceptance

- [ ] Ruby 3.3 and Ruby 3.4 CI green, with real Redis
- [ ] Enqueued Sidekiq job appears in Sidekiq Order page
- [ ] Other tenant job JID never leaks
- [ ] Retry / scheduled / dead status projection
- [ ] Adapter-specific permission
- [ ] Bounded scan and missing-job `unavailable`
- [ ] Published Rekorra gem still has no Sidekiq dependency
- [ ] Manual browser QA

## Tradeoffs

Sidekiq's public Data API warns that inspecting mutable queue structures is prone to races and that `Queue#find_job` / `JobSet#find_job` is inefficient for large queues. This adapter caps each scan (default 100 entries, maximum 500); it is **best-effort, not complete** and will report an older job as `unavailable` if outside the inspected window.

For production-scale reliable tracking, use a host-owned durable job lifecycle projection, via Sidekiq middleware or another status store, with a different adapter. A bounded Redis search is an aid for small support investigations, not an audit trail or job monitor.

Sidekiq API: https://github.com/sidekiq/sidekiq/wiki/API

## Next

Step 0004 Findings. Do not make status detection depend on a Sidekiq scan's absence implying successful completion.

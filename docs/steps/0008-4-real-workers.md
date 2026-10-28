# Step 0008.4 - Real worker process E2E

Status: PR #22, CI validation pending.

## Context

Earlier Solid Queue completion integration used perform_now plus a manually updated finished_at. Sidekiq integration checked Redis queued/retry/dead projections without starting a server process. Neither proved the queue was consumed by a real worker.

## Implementation

Dedicated Rails 8.1 / Ruby 3.4 CI job with Redis 7 and separate persistent SQLite primary and queue databases. A standalone Ruby harness (no transactional test fixtures) enqueues jobs before starting actual backend worker processes, then checks persisted business updates and provider terminal states. The harness starts Solid Queue via rake solid_queue:start, Sidekiq via its CLI, terminates subprocess groups, and uploads worker logs.

Each provider gets successful, failing and cross-tenant jobs. A real HTTP request to mounted Rekorra verifies bounded, authorized job status projections and hidden foreign identifiers. Solid Queue can show Finished and Failed; successful Sidekiq jobs disappear from Redis and remain Unavailable rather than falsely Finished, while failures go to Retrying.

## Acceptance

- [ ] Solid Queue worker executes and persists business effect, with finished execution
- [ ] Solid Queue worker failure persists and Rekorra shows Failed without exception text
- [ ] Sidekiq worker executes against real Redis/SQLite and failure enters RetrySet
- [ ] Sidekiq completed job remains Unavailable rather than fake Finished
- [ ] Foreign tenant identifiers stay absent from authorized pages
- [ ] Existing CI jobs remain green
- [ ] Post-merge CI green

## Boundaries

No throughput, crash recovery, exactly-once semantics, multi-worker concurrency guarantees, Sidekiq retry exhaustion/dead jobs, distributed transaction guarantees, or production monitoring is claimed.

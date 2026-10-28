# Step 0008.6 - Worker CI reliability

Status: PR #27 has multiple independent green full CI runs; post-merge verification pending. Tracks [issue #25](https://github.com/sergii/rekorra/issues/25).

## Root cause evidence

[Failed main run 40694611774 (first attempt)](https://github.com/sergii/rekorra/actions/runs/40694611774) and [failed run 40684496048](https://github.com/sergii/rekorra/actions/runs/40684496048) timed out after 75 seconds. The actual Solid Queue worker log artifact contains repeated `SQLite3::BusyException: database is locked` at ActiveRecord transaction begin and Solid Queue process registration/fork, repeatedly restarting supervisor children. This is **SQLite concurrent-writer contention**, not simply slow startup.

The artifact also shows Sidekiq 7.3.9 scheduler crashed with `connection_pool 3.0.2 ... pop wrong number of arguments`, an independent transitive dependency incompatibility. The job execution assertions sometimes still passed because the Sidekiq processor was running while the scheduler failed; that was not evidence of a fully healthy backend.

## Targeted changes

- In the test host only, `config/queue.yml` starts **one real Solid Queue worker process with one thread**, without a scheduled-job dispatcher that is unnecessary for the three immediately enqueued jobs. Keep the original OS subprocess `solid_queue:start`, persisted execution and true failed job state.
- The isolated SQLite queue DB permits a bounded 10-second busy wait while concurrent metadata writes serialize. The overall E2E deadline is **unchanged at 75 seconds**.
- Demo/test dependency resolution pins `connection_pool` below 3.0 for Sidekiq 7.3.x; this **does not** add a dependency to the Rekorra gemspec.
- Polling fails immediately if the worker parent exits. On failure, print the first log lines and first SQLite/exception signatures, in addition to the tail. Full worker logs remain available as an Actions artifact.

## Acceptance

- [x] Actual Solid Queue success + failure + tenant isolation in GitHub Actions
- [x] Actual Sidekiq success + retry + tenant isolation in GitHub Actions
- [x] More than one independent green CI run without re-running failed jobs
- [ ] Main post-merge CI green
- [x] No recurrent `database is locked` / Sidekiq scheduler signature in inspected successful worker log artifact

## Boundaries

A single-worker, no-dispatcher test profile is **not** a production queue sizing recommendation, and is not proof of multiple worker concurrency, scheduled dispatch, crash recovery, sustained throughput or exactly-once semantics. A future dedicated stress test should cover those behaviors on a production-like database.

# ADR 0026 - Real worker execution and provider-specific completion semantics

Status: Accepted following [Green CI 40682599257](https://github.com/sergii/rekorra/actions/runs/40682599257).

## Rationale

Inline job execution and manually injected completion timestamps do not prove queue integration. A Rails Engine job projection must respect each backend's actual information rather than infer successful completion from missing records.

## Decision

Test host owns queue dependencies, record correlation and persistent databases. A standalone smoke launches worker OS processes without transactional fixtures. It validates real domain mutations and queue state, then uses authenticated Rekorra HTTP routes to verify status display, tenant scoping and safe error handling.

Solid Queue retained completion records can be shown as Finished. Sidekiq success generally removes the job from Redis, so an absent JID must display Unavailable. Failures read from Solid Queue failed executions and Sidekiq RetrySet without rendering raw error data. No queue library is added as a mandatory gem runtime dependency.

## Limits

This is a finite E2E integration gate. Production concurrency, crash recovery, retries over full backoff windows, dead-set exhaustion, exactly-once execution and cross-database atomicity require their own tests.

## Verified evidence

[Green CI 40682599257](https://github.com/sergii/rekorra/actions/runs/40682599257): all nine jobs passed, including real worker processes and scoped Rekorra HTTP status views. Production worker crash recovery, retry exhaustion and exactly-once execution remain unproven.

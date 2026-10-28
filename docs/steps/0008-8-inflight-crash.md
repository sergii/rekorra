# Step 0008.8 - SIGKILL of an in-flight Solid Queue job

Status: Implemented in PR #30; [16/16 green CI, run 40718100382](https://github.com/sergii/rekorra/actions/runs/40718100382). Post-merge verification is recorded in the PR timeline. Issue #29.

## Verified implementation behavior (Solid Queue v1.6.0)

When a forked child exits unexpectedly, its still-running claims are failed with `SolidQueue::Processes::ProcessExitError` by the living supervisor. A replacement worker is started but failed jobs are **not** automatically dispatched. Operators may explicitly call `SolidQueue::FailedExecution#retry` after investigating whether the first attempt already produced side effects.

## CI acceptance

- Separate PostgreSQL primary and queue databases, two live forked OS workers.
- Enqueue instrumented long-running job. Its first attempt writes a durable business start marker / worker PID and increments an execution counter before sleeping.
- Verify the real claimed-execution record points to that PID and Rekorra shows Running.
- SIGKILL only the child PID while the original supervisor stays alive.
- Require ProcessExitError in Solid Queue and Failed in Rekorra. Verify no completed state and no automatic retry after a replacement worker registers.
- Invoke the backend's official FailedExecution#retry method and verify Finished in both the backend and Rekorra.
- Require execution_count == 2, reflecting two start-time side effects. This is a deliberate demonstration of idempotency risk, **not** exactly-once processing.
- Upload process logs; keep deterministic bounded waits, with no synthetic backend states.

## Caveats

The test proves one actual child-kill and explicit operator retry, not automatic recovery after supervisor-wide SIGKILL, not an auto-retry policy, and not exactly-once semantics. Recovery in production requires an operator playbook, idempotent domain writes, and monitoring for Failed executions. The published Rekorra gem has no new dependencies or write actions.

# Step 0008.7 - PostgreSQL multi-worker and queued-backlog restart

Status: PR CI pending.

## Scenario

- PostgreSQL primary and independent PostgreSQL Solid Queue database.
- Two forked worker OS processes, 36 durable jobs; require both PIDs perform work.
- Real supervisor group SIGKILL after the 36 jobs finish.
- Queue 12 jobs while workers are dead and verify none begins, then restart supervisor and verify all complete on new PIDs.
- Verify all 48 backend jobs are persisted and finished without stuck ready/claimed records, log observed jobs/s (no SLA).

## Boundary

This specifically tests recovery of unclaimed *queued backlog* after a crash, NOT rescue of an in-flight job whose claim was killed mid-execution. No exactly-once, sustained load capacity, multi-node, crash latency SLA, or scheduler claims. Test-only job/model and PG queue integration do not alter the published Rekorra gem.

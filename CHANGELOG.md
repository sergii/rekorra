# Changelog

Changes are grouped by vertical increments. For validation evidence and outstanding checks see [docs/steps](docs/steps/README.md).

## Unreleased

### Step 0008.11 phase 1 - Durable outbox scanner and leases
- Host-owned primary-DB scanner with atomic claim tokens, lease expiration, bounded attempts and review state. No need to enqueue to a second queue DB to discover a committed outbox event.
- Reconcile unknown provider outcomes before any POST; ensure an expired lease owner cannot override another scanner's state; disallow arbitrary untrusted provider endpoints.
- Operator re-open is tenant/policy/reason gated and audited. Aggregate host metrics include review/lease states.
- Dedicated PostgreSQL E2E covers two competing real scanner processes, SIGKILL while holding a lease, expiry/reclaim, lost ACK and provider receipt reconciliation, provider outage and reviewed redelivery.
- No general-purpose Rekorra retry UI, published Engine runtime change, or exactly-once external effect claim.
- See [Step 0008.11](docs/steps/0008-11-outbox-dispatch.md).


### Step 0008.10 - Transactional outbox and external delivery
- Host-owned PostgreSQL outbox intent is committed atomically with the tenant-key idempotency ledger and local business effect.
- Independent HTTP provider process persists to a separate PostgreSQL DB, dies after commit and before ACK; failed delivery is marked uncertain.
- Real Solid Queue delivery job uses stable key on explicit retry; provider deduplication makes two HTTP attempts one external effect. Read-only receipt reconciliation also proven.
- Aggregate host-only outbox health counts; no generic Rekorra retry UI, automatic scanner, external TLS/provider proof, or exactly-once claim.
- See [Step 0008.10](docs/steps/0008-10-transactional-outbox.md).

### Step 0008.9 - Idempotency and Recovery Operations
- Add host-only unique tenant-scoped operation ledger for atomic local business effects and replay-safe worker.
- Add explicit host authorization, linked-job and class checks, durable operator retry decision, and global failed/aged claim health snapshot.
- Real PostgreSQL E2E: SIGKILL claimed worker after effect commit; approved retry; duplicate independent enqueue, tenant isolation, failed/finished read-only UI status.
- No published gem retry UI, new runtime dependency or exactly-once external-effect claim.
- See [Step 0008.9](docs/steps/0008-9-idempotency-recovery.md).

### Step 0008.8 - In-flight worker SIGKILL and explicit retry
- New real OS worker E2E kills the exact process running a claimed long job under a live Solid Queue supervisor.
- Verify ProcessExitError and Rekorra Failed state without automatic retry; then use official FailedExecution#retry and assert Finished.
- Persist two distinct starts to demonstrate at-least-once side-effect risk, without exactly-once claims or changing published gem dependencies.
- See [Step 0008.8](docs/steps/0008-8-inflight-crash.md) and [issue #29](https://github.com/sergii/rekorra/issues/29).

### Step 0008.7 - PostgreSQL multi-worker and queued-backlog restart
- Real PostgreSQL primary and Solid Queue databases, two forked worker processes, 36 persisted job completions.
- Supervisor group SIGKILL and 12 queued jobs, then replacement worker completion and no stale ready/claimed jobs.
- Measured CI jobs/s is observational; in-flight claim recovery and throughput SLO remain out of scope.
- See [Step 0008.7](docs/steps/0008-7-worker-resilience.md).

### Step 0008.6 - Worker reliability regression (issue #25)
- Investigated failed Solid Queue artifacts: repeated SQLite busy locks in supervisor forked children; Sidekiq 7.3.9 scheduler failed against connection_pool 3.0.2.
- Test-only one-worker/one-thread Solid Queue profile, no unnecessary dispatcher and 10s SQLite queue busy wait; unchanged 75s E2E overall deadline.
- Pin compatible connection_pool 2.x in demo/test Gemfile, without touching the published Rekorra gemspec.
- Detect exited worker parents; include first failure signatures in CI logs while retaining full worker log artifacts.
- See [Step 0008.6](docs/steps/0008-6-worker-reliability.md) and [issue #25](https://github.com/sergii/rekorra/issues/25).

### Step 0008.5 - Installed-gem Chrome Hotwire and CSP acceptance (PR #26)
- Added two external Rails host Chrome jobs (Propshaft/Sprockets), using the built installed gem outside the repository.
- Verified real Turbo/Stimulus, pagination/back, draft-safe association lookup, persisted forms, enforced nonce CSP and asset HTTP 200.
- Added opt-in `config.importmap_enabled` for host-owned Importmap loading, false by default and no mandatory Hotwire dependencies.
- Full production deployment, reverse proxy, CDN/cache behavior, Safari/VoiceOver and production security review remain open.
- See [Step 0008.5](docs/steps/0008-5-production-assets.md) and [ADR 0027](docs/adr/0027-host-importmap-hotwire.md).

### Step 0008.5 phase 2 - Opt-in Hotwire browser acceptance
- Added optional test-host Importmap, Turbo and Stimulus, imported through a real `application.js` entrypoint.
- Chrome checks Turbo Drive pagination and browser-back navigation, Stimulus connect and loading-state cleanup.
- Browser acceptance is separate from ordinary rake test discovery; a separately installed external-host browser journey and CSP remain unverified.
- See [Step 0008.5](docs/steps/0008-5-production-assets.md).

### Step 0008.5 - Production asset precompile (phase 1)
- Added independent installed-gem production `assets:precompile` smoke for Propshaft and Sprockets.
- Verify three fingerprinted Rekorra CSS/JS files exist and contain the expected source behavior.
- Real Turbo/Stimulus external-host browser E2E and production CSP remain open.
- See [Step 0008.5](docs/steps/0008-5-production-assets.md).

### Step 0008.4 - Real worker E2E (CI green)
- Added separate worker-process E2E for Solid Queue and Sidekiq with persisted SQLite, Redis and HTTP checks.
- Verified real worker transitions, failed/retrying behavior and tenant isolation without faking terminal timestamps.
- Preserved completed Solid Queue records in the test host to prove Finished status.
- See [Step 0008.4](docs/steps/0008-4-real-workers.md) and [ADR 0026](docs/adr/0026-worker-e2e.md).

### Step 0008.3 - Installed Rails asset hosts (CI green)
- Added four independent installed-gem host smokes for Propshaft/Sprockets with and without Turbo/Stimulus railties.
- Verify CSS and JS requests actually return HTTP 200 with expected content.
- Clear transient index loading UI on Turbo lifecycle, with Chrome test.
- See [Step 0008.3](docs/steps/0008-3-asset-hosts.md) and [ADR 0025](docs/adr/0025-rails-host-assets.md).

### Step 0008.2 - MySQL 8.4 host compatibility (CI green)
- Added a service-backed MySQL 8.4 test-host job against Rails 8.1 / Ruby 3.4, preserving the independent SQLite queue.
- Kept mysql2 test-host-only, outside the gem runtime dependencies.
- Recognize MySQL backtick-quoted table names in SQL query-bound tests; remove unsupported unique_by from both demo seed insert_all call sites.
- See [Step 0008.2](docs/steps/0008-2-mysql.md) and [ADR 0024](docs/adr/0024-mysql-compatibility.md).

### Step 0008.1 — PostgreSQL host compatibility
- Added real PostgreSQL 16 CI service and full Rails 8.1 / Ruby 3.4 integration test run using PostgreSQL primary.
- Preserved independent SQLite Solid Queue database and all existing Rails compatibility/Chrome/packaging gates.
- Corrected a flaky Access Audit privacy assertion to compare exact persisted values instead of timestamp substrings.
- See [Step 0008.1](docs/steps/0008-1-postgresql.md).

### Step 0008.0 — Compatibility and packaging
- Added Ruby 3.3/3.4 × Rails 8.0/8.1 four-way integration CI.
- Added isolated .gem build and standalone Rails host HTTP/asset smoke.
- Explicitly retained production-readiness caveats.
- See [Step 0008.0](docs/steps/0008-production-readiness.md).

### Step 0007 — Access Audit
- Added provider-neutral, opt-in Access Audit event, registry, resolver and read-only timeline with a separate policy.
- Added host-owned ActiveRecord adapter and demo storage; no runtime audit gem or Rekorra migrations.
- Instrumented authorized Order Show and successful CRUD, with audit/domain transaction coupling in the demo.
- Added security tests and ADR 0021; PaperTrail Activity remains a separate module.
- See [Step 0007](docs/steps/0007-access-audit.md).

### Step 0006.4 — Native Typed Form Fields
- Inferred Rails checkbox/number/date/datetime-local/textarea inputs from host columns.
- Rejected invalid structured POST/PATCH values before assignment.
- Added CaseRecord demo typed attributes, CRUD/security and browser checks.
- See [Step 0006.4](docs/steps/0006-4-native-typed-fields.md).

### Steps 0006.1–0006.3 — Advanced Resource Extensions
- Optional progressive association lookup preserves unsaved form drafts and selected belongs_to records.
- Optional Pundit authorization and strict SQL-scope adapter, tested with real policies.
- Rails enum field widget and server-side value allowlist, with separate CaseRecord demo.
- Real Chrome draft-preservation and Ruby security/adapter integration tests.
- See [0006.1](docs/steps/0006-1-association-picker.md), [0006.2](docs/steps/0006-2-pundit-adapter.md), [0006.3](docs/steps/0006-3-enum-fields.md).

### Step 0006 — Advanced Resources
- Added centralized Resource field-level read and write policies with explicit host authorization.
- Prevented protected fields from leaking through ordinary Index/Show/form views, filters/sort or forged POST/PATCH payloads.
- Added bounded, tenant-scoped, server-rendered belongs_to search with pinned selection.
- Added security/association integration tests, ADR 0017 and Step 0006 log.
- See [Step 0006](docs/steps/0006-advanced-resources.md).

### Step 0005.3 — Chrome Browser Acceptance
- Added six real headless Chrome Rails browser tests for desktop, mobile, keyboard and no-JS navigation.
- Added screenshot artifacts and retained Capybara/Selenium as test-only dependencies.
- Documented the human accessibility and physical-device checks still pending.
- See [Step 0005.3](docs/steps/0005-3-browser-acceptance.md).

### Step 0005.2 — Resource Index UX
- Added sortable headers with accessible sort direction on ordinary model tables.
- Added native compact filters, removable active filter chips, empty-page headings and responsive styles.
- Added optional no-dependency JS loading hints with plain-HTML fallback.
- Added integration and asset tests, ADR 0015 and step notes.
- See [Step 0005.2](docs/steps/0005-2-resource-index-ux.md).

### Step 0005.1 — Keyset Cursor Pagination
- Added opt-in keyset strategy to ordinary model indexes with ASC/DESC and Previous/Next navigation.
- Added encrypted, expiring cursors bound to host tenant/actor context, resource query and authorized SQL scope.
- Added separate CursorUserResource demo and cursor contract/security integration tests.
- Kept offset behavior and no mandatory paginator gem.
- See [Step 0005.1](docs/steps/0005-1-keyset-pagination.md).

### Step 0005 — Resource Index v2
- Added static typed filters, declared sort columns, search and page-size configuration to ordinary Resource indexes.
- Added scoped ActiveRecord/Arel filter/query plan, bounded offset pagination and parameter-preserving HTML controls.
- Added a read-only User model/Resource and opt-in 50,000-record seed task.
- Added ADR 0013 and Step 0005 verification plan; keyset remains a follow-up.
- See [Step 0005](docs/steps/0005-resource-index-v2.md).

### Step 0004 — Findings
- Added provider-neutral Findings registry, resolver, DSL and structured evidence types.
- Added a demo host rule for captured payments on still-pending orders, with deterministic seeds.
- Added separately authorized, read-only Findings UI and validation tests.
- See [Step 0004](docs/steps/0004-findings.md).

### Step 0003.1 — Sidekiq Jobs adapter
- Added optional Sidekiq API adapter to the provider-neutral Jobs registry.
- Added demo Sidekiq worker and alternate Order resource without changing Solid Queue resource semantics.
- Explicit provider-scoped correlations and bounded, read-only best-effort Redis scans.
- See [Step 0003.1](docs/steps/0003-1-sidekiq.md).

### Step 0003 — Background Jobs
- Added optional Jobs DSL, provider-independent Job Item projection, adapter registry and resolver.
- Added host-scoped Solid Queue inspector, without parsing job arguments or displaying raw errors.
- Added demo OrderReceiptJob, explicit correlation model and separate queue schema.
- Added read-only Jobs section, authorization, tests and ADR 0011.
- See [Step 0003](docs/steps/0003-jobs.md).

### Step 0002 - PaperTrail Activity
- Added optional Activity adapter registry, DSL and server-rendered history section.
- Added a demo-host PaperTrail integration, JSON versions table and Order change history.
- Added explicit view-activity policy and per-request actor attribution on CRUD changes.
- Added historical-field allowlisting and security/regression tests.
- Deferred Jira integration to the documented backlog.
- See [Step 0002](docs/steps/0002-activity.md).

### Step 0001.6 - Context References
- Added typed, immutable ContextRef and ExternalRef identities, independent of any single provider.
- Added context DSL for internal record links and external provider references.
- Added scope- and policy-checked resolution, plus Linked context UI on Show.
- Added demo Order issue/trace fields and a tenant-scoped Organization resource.
- Added context regression tests and updated ADR 0008.
- See [Step 0001.6](docs/steps/0001-6-context-references.md).

### Step 0001.5 - External Links
- Added authorized, provider-aware external links on resource Show pages.
- Added a generic HTTPS URL builder and a Sumo Logic search URL adapter.
- Added per-provider visibility, configured domain allowlisting, and safe query encoding.
- Added demo Order links to Sumo Logic and GitHub Issues search.
- Defined future provider-neutral Context References, Jira linking, and correlation ADRs.
- See [Step 0001.5](docs/steps/0001-5-external-links.md).

### Step 0001 - First associations
- Added a real demo domain with Organization, Customer, Order, Payment and seeded records.
- Added Resource DSL, server-rendered CRUD, scoped associations and relationships.
- Added restricted search/sort, batched belongs_to rendering and relationship assignment checks.
- Added security and query integration tests.

### Step 0000 - Engine shell
- Initial mountable and isolated Rails Engine.
- Server-rendered shell with packaged CSS and theme selection.
- Demo Rails host, initial integration tests and architecture records.

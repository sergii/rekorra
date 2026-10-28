# Incremental delivery log

Every increment is vertically complete in the demo and the gem. Each record tracks changed behavior, tests and limitations.

| Step | Demo application | Gem | Status |
| --- | --- | --- | --- |
| [0000 - Bootable Engine](0000-engine-shell.md) | Rails host, engine mount, demo authentication | Isolated engine, HTML shell, themes | CI green; browser QA pending |
| [0001 - First associations](0001-first-associations.md) | Organization, Customer, Order, Payment | Resource registry, scoped CRUD and associations | CI green; browser QA pending |
| [0001.5 - External Links](0001-5-external-links.md) | Order deep links for Sumo Logic and GitHub Issues | Provider-aware resolver, link policies, secure URL generation | CI green; browser QA pending |
| [0001.6 - Context References](0001-6-context-references.md) | Order links Customer, Organization, fictional Jira issue and trace | Typed identities, scoped resolver and context DSL | CI green; browser QA pending |
| [0001.7 - Jira linking](../backlog/jira-integration.md) | Jira issue associated to Orders or investigations | Remote Issue Links adapter | Deferred to backlog |
| [0002 - Activity](0002-activity.md) | PaperTrail versioned Orders and seeded change | Optional PaperTrail adapter, protected read-only timeline | CI green; browser QA pending |
| [0003 - Jobs](0003-jobs.md) | OrderReceiptJob and Solid Queue, explicit job links | Jobs DSL, adapter registry, read-only job status panel | CI green; browser/worker QA pending |
| [0003.1 - Sidekiq adapter](0003-1-sidekiq.md) | Sidekiq worker and alternate Order resource | Read-only bounded Sidekiq API projection | CI green; browser QA pending |
| [0004 - Findings](0004-findings.md) | Pending Order with captured payment | Provider-neutral rules, evidence and read-only Findings UI | CI green; browser QA pending |
| [0005 — Resource Index v2](0005-resource-index-v2.md) | 50k-user dataset option, typed filters | Scoped AR/Arel search, filter, sort and offset pagination | CI green; browser QA pending |
| [0005.1 — Keyset Pagination](0005-1-keyset-pagination.md) | Alternate Cursor Users page | Encrypted scope-bound keyset strategy and bidirectional HTML navigation | CI green; browser QA pending |
| [0005.2 — Resource Index UX](0005-2-resource-index-ux.md) | Users and Cursor Users tables | Clickable headers, compact filters, filter chips, optional loading hint | CI green; browser QA pending |
| [0005.3 — Chrome Acceptance](0005-3-browser-acceptance.md) | Mounted Rails host in Chrome | Desktop, 390/320 px, keyboard, JS-off, screenshot artifacts | Chrome CI green; human QA pending |
| [0006 — Advanced Resources](0006-advanced-resources.md) | Protected totals, searchable Customer picker | Field-level policies, scoped bounded belongs_to lookup | CI green; manual device QA pending |
| [0006.1 — Draft-safe association lookup](0006-1-association-picker.md) | Order Customer lookup | Optional draft-preserving JS + native GET | CI green; manual QA pending |
| [0006.2 — Pundit adapter](0006-2-pundit-adapter.md) | Real test-host policy | Optional authorization and scoped relation adapters | CI green |
| [0006.3 — Enum fields](0006-3-enum-fields.md) | CaseRecord with enum state | Declarative enum select, value validation | CI green; manual QA pending |
| [0006.4 — Native typed forms](0006-4-native-typed-fields.md) | CaseRecord typed columns | ActiveRecord-derived HTML fields and strict structured-input validation | CI green; device QA pending |
| [0007 — Access Audit](0007-access-audit.md) | Host-owned audit entries for Orders | Optional event/adapter contract, scoped write & read-only timeline | Merged; Ruby and Chrome CI green; manual QA pending |
| [0008.0 — Rails compatibility](0008-production-readiness.md) | Installed-gem standalone host | Rails 8.0/8.1 with Ruby 3.3/3.4, package smoke | Merged; CI green |
| [0008.1 — PostgreSQL compatibility](0008-1-postgresql.md) | Rails host primary DB in PostgreSQL 16, SQLite Solid Queue | Full integration, authorization, filters, keyset, audit | Merged; CI green |
| [0008.2 — MySQL compatibility](0008-2-mysql.md) | Rails host primary DB in MySQL 8.4, SQLite Solid Queue | Full integration and 50k-row SQL bounds | Merged; post-merge CI green |
| [0008.3 — Asset host compatibility](0008-3-asset-hosts.md) | Standalone installed Rails hosts, Propshaft/Sprockets and optional Hotwire | Asset HTTP delivery and Turbo lifecycle cleanup | Merged; post-merge CI green |
| [0008.4 — Real worker E2E](0008-4-real-workers.md) | Standalone Solid Queue and Sidekiq OS workers, SQLite + Redis | Real execution, failed/retrying, scoped statuses | Merged; post-merge CI green |
| [0008.5 — Production assets](0008-5-production-assets.md) | Installed gem in two production hosts | Propshaft/Sprockets precompile, demo + installed-gem Chrome Turbo/Stimulus/CSP | PR #26 CI pending; live deployment QA pending |

| [0008.6 — Worker CI reliability](0008-6-worker-reliability.md) | Single-worker test queue and bounded SQLite lock wait | Sidekiq 7.3/pool compatibility, worker startup diagnostics | PR #27 CI green; post-merge pending |

| [0008.7 - Worker resilience](0008-7-worker-resilience.md) | PostgreSQL primary/queue and 2 worker OS processes | SIGKILL and queued backlog resume | CI pending; in-flight rescue not tested |

| [0008.8 - In-flight SIGKILL](0008-8-inflight-crash.md) | Real claimed job and child-process crash on PostgreSQL | Failed vs explicit retry, UI status and duplicate attempt | PR CI pending |

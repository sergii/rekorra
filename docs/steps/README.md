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

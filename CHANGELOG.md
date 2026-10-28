# Changelog

Changes are grouped by vertical increments. For validation evidence and outstanding checks see [docs/steps](docs/steps/README.md).

## Unreleased

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

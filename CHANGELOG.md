# Changelog

Changes are grouped by vertical increments. For validation evidence and outstanding checks see [docs/steps](docs/steps/README.md).

## Unreleased

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

# Changelog

Changes are grouped by vertical increments. For validation evidence and outstanding checks see [docs/steps](docs/steps/README.md).

## Unreleased

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

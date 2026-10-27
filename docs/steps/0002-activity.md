# Step 0002 - PaperTrail Activity

Status: Implemented in feature branch; CI and manual browser verification pending.

## Demo Rails application

- Installs `paper_trail ~> 17.0` only in the root development Gemfile, **not** in `rekorra.gemspec`.
- Adds a host-owned `versions` table with JSON `object` and `object_changes` columns and item index.
- Adds `has_paper_trail` to the `Order` model for create/update/destroy.
- Seeds an initial pending Order then changes it to paid, so the demo has visible version history.
- Configures a demo-only actor identifier `demo-organization:<slug>` and explicit `view_activity?` permission (Acme only). This actor is an organization, **not** a real human identifier.

## Rekorra Engine

- `activity do` resource DSL: provider source, explicit policy, allowed field list, bounded event count.
- Optional adapter registry with `Rekorra::Activity::Adapters::PaperTrail`.
- Read-only server-rendered Activity section on Order Show.
- Field-level output allowlist; does not render the whole PaperTrail `object` or unapproved `object_changes`.
- Per-request write actor propagated through the registered adapter to PaperTrail, with scoped restoration.
- No JavaScript bundle, no Rekorra-owned database tables, no runtime dependency on PaperTrail.

## Validation checklist

- [ ] Ruby 3.3 and 3.4 CI green on Rails 8.x
- [ ] Order version create and update shown
- [ ] Unauthorized viewers cannot see activity or trigger adapter queries
- [ ] Tenant isolation intact
- [ ] Web CRUD attributes new versions to demo actor
- [ ] Unapproved fields hidden and HTML values escaped
- [ ] Activity list size bounded and wrong configuration rejected
- [ ] Responsive browser / color-theme visual QA

## Security and behavior constraints

- PaperTrail is a **change history**, not a record-view access log. Browsing a record does not create a version.
- A PaperTrail version's `whodunnit` must come from the host's authenticated actor, not a fabricated username.
- JSON storage avoids the unsafe YAML deserialization pattern for the demo; host apps choose their own PaperTrail retention, encryption and sensitive-attribute `skip:` settings.
- Only fields explicitly configured in Resource DSL are displayed; this does not prevent other sensitive information from being stored inside host-owned PaperTrail versions.
- The timeline is capped and read-only. Destroyed records cannot be viewed in the current CRUD show page.
- No timeline pagination, custom event ingestion, audit-review UI or PaperTrail version restoration yet.

## Next

Step 0003 - ActiveJob/Solid Queue job context, with Jira integration remaining in backlog.

# Step 0006 — Advanced Resources: field policies and association lookup

Status: Feature branch; CI pending.

## Goals

Improve ordinary Rails Resource CRUD, not Findings or a custom dashboard:
- Explicit, reusable field read/write permissions enforced in views, filters, sort, and mutation endpoints.
- Replace the first-100-only belongs_to selector with scoped and bounded server-side search, usable with large host tables.

## Core

- Resource DSL \`field_policy :total_cents, read: :view_total_cents?, write: :edit_total_cents?\`.
- Each field policy is declared once per model column. Predicates are delegated to the host's existing \`authorize_with\`, with separate checks at the class and record level. No hard-coded role names.
- Index hides forbidden columns, filter UI, and sortable fields. A request explicitly trying to sort/filter a forbidden column returns HTTP 403, and text-search excludes protected columns.
- Show and forms omit restricted fields. Index rows additionally check policy against each individual record; a denied row-level field renders "Restricted" rather than running a formatter.
- Server-side strong parameters reject forged protected fields on POST/PATCH with HTTP 403, before calling \`assign_attributes\` or persisting any changes.
- No new database tables, authorization framework or mandatory dependency.

## Association lookup

- For belongs_to fields, form renders a native, separate GET search form; matching entries are selected through the same host \`scope_with\` and \`:show?\` policies.
- Server-side search checks a declared model column (name, email or number), escapes SQL LIKE wildcards, truncates the query and limits results to at most 50.
- An already-selected related record is pinned, even if outside the first 50 matches (maximum 51 records plus empty option). Association writes still validate selected IDs through the host's scope on submit.
- No global association list or unscoped lookup, no JS/autocomplete network calls.

## Acceptance

- [ ] Ruby 3.3 and 3.4 integration CI
- [ ] Browser CI and existing Resource Index tests
- [ ] Restricted fields absent from Index, Show and forms
- [ ] Protected filters/sort and forged POST/PATCH rejected
- [ ] Unprotected fields remain editable without privileged field access
- [ ] Search over 100+ host records returns a matching late record
- [ ] Selected relation remains available when it is outside the first 50
- [ ] Search and mutation never leak or select foreign-tenant records
- [ ] Manual device/browser review

## Boundaries

- Model-level field policies determine which columns may participate in index search/sort/filter. Record-level policies are checked when rendering each value, but a **record-dependent privacy rule** also requires an adequately scoped relation (and potentially a separate SQL policy filter); field redaction alone does not make arbitrary SQL search over restricted rows safe.
- Field policies govern the Resource's Index/Show/Form, **not** the domain's own logs, external context, or custom renderer internals. Hosts must separately protect Activity, Jobs, Findings and any custom view.
- GET-based lookup reloads the page and **does not preserve unsaved changes** in other form inputs. Search may use leading-wildcard LIKE and must be backed by suitable indexes or a dedicated lookup adapter for large/production tables.
- Association picker still requires the host's explicit policy; it is not an implicit permission to assign a related record. It handles belongs_to only, not polymorphic/multi-select.
- No Pundit integration, attachment upload, enum widgets, new custom components, or field-level policies on nested association records in this step.

## Next

Step 0006.1 may introduce a debounced, accessible optional lookup adapter to preserve drafts, then address Pundit integration, field types and polymorphic associations independently.

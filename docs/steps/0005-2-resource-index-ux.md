# Step 0005.2 — Resource Index UX

Status: Ruby and real Chrome CI green; human/device/screen-reader QA pending.

## Goal

Make everyday model indexes useful with clickable sortable headers, compact filters, removable filter chips, mobile-friendly rows and an optional loading hint. Both offset and keyset modes share the same HTML and existing Query contract.

## Implemented

- Only fields in the declared sort_by allowlist are rendered as sortable links. The active header has aria-sort and labels describe the next ascending/descending action.
- Sort links retain normalized search, filters and rows-per-page and reset both offset page and keyset cursor. The sort selection remains available even on an empty page.
- Native details/summary groups advanced filters; open by default when normalized filters are active.
- Active filter chips remove a single validated filter value. Clear filters retains search/sort/page size; no arbitrary request parameters are echoed.
- Existing semantic table and data-label mobile cards are enhanced with focus-visible, touch targets, responsive pagination and dark-theme tokens.
- A tiny packaged vanilla JavaScript asset marks result content aria-busy during native GET submit or internal link navigation, clears stale busy state on pageshow and never intercepts or cancels navigation.
- Plain forms, sorting links, filters and pagination continue to work without JavaScript. No npm, bundler, Turbo or React dependency.

## Guardrails

- Query, authorization, relation scoping and SQL predicates are unchanged from Steps 0005 and 0005.1.
- Active filters come from normalized filter_values; changes always restart pagination.
- The loading indicator is best-effort: a full-page navigation may occur before the browser paints it. It is not a network progress measurement, an AJAX loader or a background fetch.
- Default aria-busy remains absent until JavaScript enhances the page; forms and navigation work normally without it.

## Acceptance

- [x] CI green Ruby 3.3 and Ruby 3.4
- [x] Accessible heading sorting and direction toggle
- [x] Sorting preserves validated state and resets offset/cursor
- [x] Empty pages retain sortable heading controls
- [x] Details are compact when unused and open for active filters
- [x] Filter chip removal and Clear filters preserve unrelated state
- [x] JS/CSS assets load from mounted Rails Engine; no-JS forms still work
- [x] Existing 50k Users test and access controls remain green
- [ ] Physical mobile browser, keyboard and screen-reader visual QA

CI evidence: [GitHub Actions run 40607479397](https://github.com/sergii/rekorra/actions/runs/40607479397), Ruby 3.3 and 3.4, **117 tests and 659 assertions, 0 failures/errors/skips** per job. The pre-existing 50,000-record Index test remains green. Automated real-Chrome mobile and keyboard coverage passed in [Step 0005.3](0005-3-browser-acceptance.md); human screenshot inspection, physical-device and screen-reader QA remain pending.

## Not included

No AJAX, actual network timing measurement, custom skeleton renderer, column visibility personalization, persisted saved views or custom data-grid library. Wide-table visual QA is outstanding.

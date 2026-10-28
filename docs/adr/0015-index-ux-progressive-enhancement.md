# ADR 0015 — Native-first Resource Index UX with optional loading hint

Status: Accepted; Step 0005.2 automated integration CI passed, manual browser QA pending.

## Decision

Extend the common Resource Index view, not the query engine. Only explicitly declared sortable fields become header links. Active headings expose aria-sort, with meaningful next-direction link labels. Sorting resets page and cursor but keeps normalized search, filters, direction and page size where relevant.

Use native HTML details/summary for advanced filters and source active chips exclusively from validated Query filter_values. Each remove link drops exactly one value. Retain the semantic table and mobile data-label pattern, visible keyboard focus and theme CSS.

Pack a small independent JavaScript file through the engine asset pipeline. It may set a best-effort aria-busy/loading hint when the user submits a native GET form or follows unmodified same-origin index navigation. It does not call preventDefault or fetch, does not take over native navigation, and is not required for page operation. Browser back/forward cache clears stale busy state on pageshow.

## Safety

No SQL or permission logic moves to JavaScript. Existing host scope, row authorization, query allowlists and signed keyset cursor remain authoritative. No arbitrary request column or unvalidated filter value is used to generate a link.

## Alternatives

Mandatory Turbo/Stimulus, a JS grid framework, client-side sorting and synthetic loading skeletons were deferred. They would add dependencies and imply behavior that a native page transition does not guarantee.

## Follow-ups

Run manual browser QA for phone widths, keyboard and assistive technology. Consider an optional reactive/Hotwire enhancement later, preserving native GET fallback.

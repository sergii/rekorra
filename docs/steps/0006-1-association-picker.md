# Step 0006.1 — Draft-safe Association Picker

Status: Ruby 3.3/3.4 and Chrome CI green; manual mobile/Safari QA pending.

A small optional vanilla JS asset intercepts scoped native GET association lookups. It fetches the existing authorized Rails HTML, parses matching options and updates **only the belongs_to select**. Unsaved record fields and the previously selected related record remain intact, even across consecutive searches. The JS cancels stale requests, exposes an aria-live status, and never changes server-side permissions, query caps or foreign-key validation.

Without JS, the original GET fallback still works but reloads the page and loses unsaved draft values. No dedicated search API, global model query, new JS framework, debounce, or polymorphic lookup is added.

Acceptance: [CI 40612793162](https://github.com/sergii/rekorra/actions/runs/40612793162), including real Chrome lookup against 75+ tenant-scoped Customers, unsaved draft and selected option preservation. Human device, keyboard and VoiceOver review remain pending.

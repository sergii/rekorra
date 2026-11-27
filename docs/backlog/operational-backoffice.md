# Operational backoffice roadmap (2026-11-27)

Rekorra is a Rails-native operational backoffice, not a model browser. Build business workspaces for real staff. The CRM dogfood domain is the primary product demonstration; all demo and regression scenarios use synthetic CRM data.

## Decisions and boundaries

- One modular Rails Engine gem; host models, services, transitions, policies and business invariants stay host-owned. Explicit resource registration only. Never expose arbitrary models.
- Target Rails 7.x and 8.x, with supported Ruby/Rails combinations determined by upstream requirements and CI. Existing gemspec is Rails 8-only; support is not achieved by relaxing constraints alone. Legacy compatibility is not upstream security support.
- Own layout, assets, tokens, icons and JS runtime. Release-time prebuilt assets in the gem; no Node, npm, host Importmap, Tailwind or pipeline setup required. Dedicated fingerprinted static endpoint/CDN option: allowlisted manifest paths, MIME, cache, CSP and mount-prefix tests. Current Propshaft/Sprockets integration remains until replacement passes.
- HTML-first: evaluate Phlex/Phlex-Rails with RubyUI-inspired components; keep public semantic Ruby DSL renderer-independent. Tailwind CLI + esbuild, isolated Stimulus/TypeScript and optional Turbo or fetch; avoid mandatory React, allow complex islands when justified. Herb is ERB tooling, ReActionView an optional separate PoC. No adoption claims until compatibility/security tests pass.
- Separate DataTable from advanced DataGrid. Shared scoped query engine across table/list/cards/Kanban/timeline; server-side sort, allowlisted filters/search, offset and cursor pagination. Optional Ransack/Pagy adapters; evaluate TanStack vanilla or Tabulator for complex grids.
- DataTable: quick tabs, chips, typed filters (text/boolean/enum/date/number/association), selection, row/bulk actions, URL state, column visibility/ticket/resize/pin, density, sticky headers, keyboard navigation, empty/loading/error states, exports, saved views, grouping/aggregates; virtualization and realtime later. Scope before data, counts and exports.
- Inspector: DSL header/title/subtitle/avatar/status, sections, fields, metrics, tabs, related records, activity, findings, jobs, audit, authorized actions; split/overlay/full-page modes, resizable and pinnable, deep link and preserved query/scroll, responsive keyboard/focus behavior. No separate weaker authorization.
- Navigation: left collapsible sidebar, icon rail and focus mode; explicit global tree > resource metadata > namespace > General fallback. Business domains override Ruby names; alphabetic/custom ticket, nested groups, role-aware visibility, search, favorites, recent, persisted preferences, command palette, technical resource catalog. Workspaces/pages distinct from resources, reusable across contexts. Counters are permission/tenant scoped, lazy/batched; no N+1. Hiding is not authorization.
- Status cards are scoped filters, findings are evidence, Inbox/My Work is actionable work (assignment/team, severity separate from priority, due time, status, snooze/resolve, history). Not every failed item needs manual work; successful records may have findings.
- Operational Kanban: columns are process stages, not generic failed/succeeded buckets; independent health (healthy/pending/warning/overdue/failed/blocked/unknown/recovering), stage-entry time, per-stage SLA, findings, explicit empty lanes, all/attention/my work/team modes, evidence/timeline in Inspector. Unknown external outcome is not failed. No drag to confirmed; authorized domain transition only, read-only default. Counts and cards obey identical scope/filter; bounded lane queries and terminal history windows. Later p95/p99, throughput, SLA and bottleneck analytics.
- Security: host authentication, host + step-up MFA, optional standalone invited staff identity. TOTP (Google Authenticator compatible, no Google API), encrypted secrets, atomic replay prevention, rate limiting, recovery codes hashed/single-use, session rotation/expiry/revocation and account disable. WebAuthn/passkeys and OIDC/SSO later; verify assurance and role mappings, intersect host and Rekorra restrictions. CSRF, CSP/XSS, tenant/row/field/action access, masked data, security audit, no secret logging, export authorization, fresh MFA and separation of duties for sensitive actions. Security Center and access reviews later. Same-process engine is not a separate trust boundary. Never claim production readiness without independent review.

## Delivery plan

| Step | Scope | Acceptance gate |
|---|---|---|
| 0009.0 | CRM dogfood foundation + navigation first slice | Namespaced real Rails models, explicit resources, seeded two tenants, read-only list/show, permission-filtered nested navigation and regression tests |
| 0009.1 | Standalone assets + Rails 7/8 matrix | Installed gem in host with no asset pipeline; both Rails majors with valid Ruby versions, CSP/cache/security checks |
| 0009.2 | Phlex PoC + design system + component playground | Compare rendered HTML, accessibility, dark/light and browser screenshots; keep semantic DSL |
| 0009.3 | Application shell / navigation v2 | Explicit tree, collapse/icon/focus, search, favorites, role filtering, counters without query amplification |
| 0009.4 | DataTable v3 / Cards / Inspector | Shared query, deep links, column controls, keyboard, tenant/field authorization across renderers |
| 0009.5 | CRM lifecycle + Operational Kanban | Stage/health independent; exact scoped 0/2/1/0 attention scenario; no unsafe drag/retry |
| 0009.6 | Security gateway and MFA | Host/step-up contracts, TOTP enrollment and replay/rate/session/recovery negative tests |
| 0009.7 | Workspaces, status cards and Inbox | Assigned work, evidence, due times, scoped counts and audited resolution |
| 0009.8 | Business actions and approvals | Explicit domain service, idempotency, fresh MFA and two-person approval where needed |
| 0009.9 | Security Center and production review | Session/identity management, access reviews, threat model and independent verification |
| Later | Advanced grid, integrations, agent/MCP interface | Explicit bounded permissions, no bypass, opt-in adapters |

Security contracts and negative tests apply to every slice, not only the dedicated security phase. All APIs in roadmap beyond implemented code are proposals. Keep generic worker recovery and outbox coverage in CRM scenarios.

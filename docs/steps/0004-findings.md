# Step 0004 — Findings

Status: Automated CI passed on Ruby 3.3 and 3.4; mobile browser QA pending.

## Demo host

- Adds a single domain-specific, read-only consistency evaluator `PaidButPending`.
- An Order with status `pending` and total captured payments at least equal to order total produces a warning.
- Adds deterministic seeded Order ACME-1002 with one captured payment and still-pending status.
- A normal Order, partially paid order, or an Order no longer pending has no warning.

## Engine

- Provider-neutral `Findings::Registry`, `Findings::Resolver`, `Findings::Definition`, `Findings::Finding`, and `Findings::Evidence`.
- Resource DSL: `findings do; rule :paid_but_pending; authorize :view_findings?; limit 10; end`.
- Separate authorization before evaluating any rule, after host record scoping and `:show?`.
- Read-only Findings section on Show; no persistence, new tables, JavaScript or automatic remediation.
- Rule evaluation is host-owned, including host-specific business relationships. The engine owns only contracts and presentation.

## Acceptance

- [x] Ruby 3.3 / 3.4 CI passed
- [x] Paid/pending mismatch produces a warning with explicit evidence
- [x] Matching paid status, partial capture and no payment produce no warning
- [x] Cross-tenant, anonymous and denied policy prevent evidence disclosure
- [x] Denied policy never invokes rules
- [x] Invalid payloads, configuration and rule results fail closed
- [x] HTML escaping of potentially unsafe text and bounded output
- [ ] Mobile visual QA

[CI run 40601346550](https://github.com/sergii/rekorra/actions/runs/40601346550): 87 tests, 392 assertions, 0 failures/errors on each Ruby 3.3 and Ruby 3.4 job.

## Limitations

This is **on-demand detection**, not a background rule engine, persisted case management or alert delivery. A finding's presence can change when data changes. No severity-based escalation, deduplication across multiple records, acknowledgement workflow, confidence score or auto-remediation is included.

## Next

Expand rule-conformance tests, or add a bounded read-only Findings index in a separate increment. Follow the same pattern before considering Observability/Activity/Jobs-derived findings or an Investigation model.

# ADR 0012 — Host-owned Findings rules with structured evidence

Status: Accepted for Step 0004.

## Decision

Rekorra's generic module owns rule registration, authorization, bounded evaluation and safe server-rendered presentation. A host supplies domain rules by implementing `evaluate(record:)`, returning a `Findings::Finding` or `nil`.

Each `Finding` has a code, severity (`info`, `warning`, `critical`), title, description and up to eight structured `Evidence` values. Scalar evidence and labels have bounded lengths, cannot include control characters and are HTML-escaped by Rails templates.

## Authorization and scope

The engine must first load the source record through the host's tenant-scoped relation, authorize `:show?`, then check a separate `:view_findings?` policy before invoking any rule. A domain rule only reads records linked through the already authorized Order; never query global payments or tenants. Other hosts must supply similarly scoped rule implementations.

## Rules versus events

A Finding represents the evaluated **current state**, not a historical event, immutable audit fact or persisting case. A rule may return a finding on one page load and nil after data changes. Rekorra never executes suggested remediation or writes business records from a rule.

## Extensibility

Rules are independent registered objects, not tied to PaperTrail, Sidekiq, Solid Queue or particular Rails models. Later adapters can read authorized technical signals, but must preserve evidence provenance and not assume a missing Redis job was successful.

No Rekorra-owned tables, background scheduler, AI inference, alerts, findings aggregation or multi-tenant dashboards in this step.

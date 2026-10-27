# ADR 0009 - Correlation and investigations

Status: Proposed; architecture notes, not implemented.

## Distinct identifiers

- Business reference: order, customer, tenant, organization.
- `request_id`: one HTTP request.
- `trace_id` / `span_id`: OpenTelemetry context for distributed operations.
- `job_id`: one background task (including retries as provider-specific metadata).
- `correlation_id`: optionally identifies a longer business workflow spanning multiple traces.
- External reference: Jira issue, GitHub issue, Intercom conversation, Sentry error, etc.
- Investigation ID: optional Rekorra grouping, not a replacement for all identifiers.

Don't assume a request ID equals a trace ID or that a trace contains the entire payment lifecycle. Rekorra should use IDs to generate provider links and resolve permitted context; not replicate full traces/log archives.

## Proposed modules (not yet implemented)

- `ContextResolver`: resolves typed references via registered adapters.
- `Investigation`: optionally persisted collection of references and evidence, with many-to-many links.
- `EvidenceRef`: provenance, timestamp, confidence, and validation method.
- Future read-only context tools for AI/MCP/Rovo, subject to the same policies.

An Investigation may initially have only an external issue identifier; no order/customer ID is required.

## Adjacent but separate

- Activity/PaperTrail describes record changes.
- Access Audit describes who accessed Rekorra records (may later integrate `console1984`/`audits1984`).
- Authentication and SSO belong to host Rails application's authentication adapters.
- AI proposals must not initiate unsafe changes automatically. Human review and audited domain actions are separate.

## Delivery sequence

0001.5 External Links -> 0001.6 Context References -> 0002 Activity/PaperTrail -> 0003 technical context/jobs -> later Investigations and optional AI integrations. Jira linking (formerly 0001.7) is deferred to [backlog](../backlog/jira-integration.md).

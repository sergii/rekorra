# Step 0007 — Access Audit

Status: Implemented on feature branch; integration and browser CI pending.

## Purpose

Access Audit is **not** a model version history (PaperTrail Activity), background job history, web analytics or a request log. It records who was authorized to view a single record and which successful CRUD operations changed records.

## Implementation

- `Resource.access_audit do; source :active_record; authorize :view_access_audit?; limit 10; end`.
- `AccessAudit::Event` immutable, validated scalar envelope: action, record type/id, actor key, tenant key, request ID, occurrence time. No params, passwords, before/after field values, cookies, user agent, IP, raw error or backtrace.
- `AccessAudit::Registry` adapter contract `write!(event:)` and `entries(record:, tenant_key:, limit:)`; `AccessAudit::Resolver` checks an independent record-specific viewing policy before requesting bounded entries.
- `AccessAudit::Adapters::ActiveRecord` uses a host-selected model name, constantized lazily. The host creates and retains its own audit table and indexed tenant/record columns. No new tables in Rekorra Engine and no extra runtime gem.
- Demo host uses `DemoAuditEntry`, and explicitly maps authenticated actors and tenants to stable keys. Its Order Resource is audited; other resources are unchanged.
- Authorized Order Show requests write an access event **before the audit section is read**. Denied and anonymous requests are not logged by this first slice.
- Successful create, update and destroy events are emitted only after a successful domain mutation. For the demo host storing audits in the *same ActiveRecord database*, both operations occur inside a shared transaction. Audit write failure rolls back a mutation.
- A separate `view_access_audit?` authorization controls the Show page's read-only timeline, which displays only action, actor key and time for the current tenant/record.

## Acceptance

- [ ] Ruby 3.3 / 3.4 integration CI green; Chrome CI green
- [ ] Authorized Show recorded with tenant, actor, record and correlation ID
- [ ] No event for unauthenticated/denied access
- [ ] Other tenant's entries never shown
- [ ] CRUD success produces single correct action; invalid mutation produces none
- [ ] Forbidden parameter mutations are not recorded as success
- [ ] Audit sink failure rolls back demo AR mutation
- [ ] Second in-memory adapter works, with independent reader policy
- [ ] Malformed payloads and oversized result sets rejected
- [ ] Manual browser/phone accessibility QA

## Important limits

- This is **record Show access auditing**, not Index/search/API/console access coverage. Denied attempts, edit/new form reads and bulk actions are not logged yet.
- An authorized Show is logged when controller processing starts, not guaranteed after the HTTP response successfully reaches the browser.
- The demo identifies an *organization*, not a distinct human administrator. Real hosts must supply a per-user `actor_key` if they need individual attribution.
- A shared database transaction can guarantee all-or-nothing for host DB audit writes. Remote sinks/queues, independent DB connections or external services cannot promise atomic commit. Production compliance needs reliable outbox/durable delivery, retention, access controls and integrity/immutability policies.
- A missing/failing writer raises rather than silently skipping the audit; no fallback to unlogged reads or writes. Production hosts must choose failure policy deliberately.
- Audit metadata may itself be sensitive. Rekorra's UI uses a separate policy and an explicit tenant-scoped query; host must enforce further storage security and appropriate retention.
- No `console1984`/`audits1984` coupling yet; these are potential separate adapters, not required dependencies.

## Next

Consider Step 0007.1 for denied-attempt instrumentation (outside the resource action), actor-level attribution in demo, outbox support and dedicated Access Audit index/export once there is a tested multi-actor host.

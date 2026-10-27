# Step 0001.6 - Context References

Status: Implemented in feature branch; CI verification pending.

## Demo host application

- Adds optional `support_issue_id`, `support_issue_key`, and `trace_id` fields to the Order table, without adding any tables to Rekorra itself.
- Seeds a fictional Jira issue and fictional trace on Order ACME-1001 (not a real provider connection).
- Registers an Organization resource with read-only permissions and tenant scoping.
- Order context links to Customer and Organization and displays Jira issue / Datadog trace identities.

## Rekorra engine and DSL

- Introduces immutable `Rekorra::ContextRef` (application, environment, tenant, resource, id).
- Introduces immutable `Rekorra::ExternalRef` (provider, instance, kind, id, display_key).
- Adds a `context do` DSL with `record` and `external` declarations.
- Resolves internal records using the host's scoped relation and record authorization; unregistered or inaccessible targets cannot be linked.
- Requires explicit policy for external references; denied callbacks are not invoked.
- Renders Linked context as server-side HTML with no new JS dependencies.
- External identities are deliberately **not** rendered as URLs without an explicitly configured provider builder.

## Verification

- [ ] Ruby 3.3 and 3.4 GitHub Actions green
- [ ] Internal associations linked only after policy + tenant scope
- [ ] External metadata hidden without separate permission
- [ ] Denied callbacks not executed
- [ ] ContextRef identity distinguishes tenant and environment
- [ ] No phantom external entries for missing identifiers
- [ ] Mobile browser UI screenshots

## Deliberately excluded

- Fetching Jira, Datadog or provider data.
- Persisting investigations, evidence, graph edges or duplicate telemetry.
- Automatically interpreting AI suggestions as verified links.
- Linking a Jira issue back to Rekorra via Remote Issue Links (Step 0001.7).

## Next

Implement Jira Remote Issue Links behind an opt-in integration that uses these identities and the existing authorization and External Links contracts.

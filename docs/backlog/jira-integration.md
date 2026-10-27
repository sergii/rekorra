# Backlog - Jira integration

Status: Deferred at user request before Step 0002. Not implemented.

## Why keep it

The provider-neutral `ExternalRef` and `ContextRef` contracts from Step 0001.6 provide identity and authorization boundaries independent of Jira's vocabulary. Jira would become an optional adapter, not a dependency of Rekorra Core.

## Proposed future vertical slice

- Add a fictional Jira issue linked to an Order in the demo host.
- Build a dedicated adapter for Jira Cloud Remote Issue Links, with stable issue ID / mutable display key.
- Generate authenticated `Jira issue -> Rekorra Order` remote links only when tenant and policies allow the source record.
- Allow an unresolved issue with no record ID; do not invent associations.
- Add request-level tests against an HTTP stub, without live Jira credentials.
- Ensure idempotency, provider instance identity, retries, API error handling and no token leakage.
- Keep SSO/login at the provider boundary; do not mirror Jira access rights into Rekorra automatically.

## Not in the current milestone

No Jira API requests, Jira OAuth, background sync, Rovo/A2A/AI or persisted Investigation models.

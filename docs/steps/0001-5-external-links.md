# Step 0001.5 - External Links

Status: Implemented in feature branch; CI and browser verification pending.

## Demo Rails app

`OrderResource` exposes:
- Sumo Logic `See logs`: deep link filtered by numeric order and tenant ID, last 24 hours (demonstration search).
- GitHub Issues `Find related issues`: URL-encoded search for an order reference.
- Per-provider visibility: the sample policy allows Sumo links for Acme but not Globex.

The sample URLs do not prove that those external services contain events for demo orders.

## Rekorra gem

- `external_link` in the resource DSL with `provider`, `label`, and mandatory `authorize`.
- Resolver and `:url` / `:sumo_logic` builders.
- HTTPS and exact-host allowlist.
- Fixed provider path plus encoded scalar query parameters.
- Link card on Show, accessible from HTML only, `rel="noopener noreferrer"` and no-referrer policy.
- No provider credentials, network requests, new migrations or JS bundle.

## Verification

- [ ] CI tests complete for Ruby 3.3 and 3.4
- [ ] Authorized link presence and encoded provider filters
- [ ] Forbidden link hidden before callbacks run
- [ ] Cross-tenant and anonymous requests do not expose links
- [ ] Reject insecure URL, credentials, off-allowlist host and unsafe path
- [ ] Provider-unconfigured behavior covered
- [ ] Manual mobile/browser visual QA

## Known limitations

- First provider implementations are generic URL and Sumo Logic only. Grafana/Datadog/Jira deep link builders need their own contracts and tests.
- No Jira API, sync, persistent external references, investigations, telemetry or AI.
- No direct evidence of which logs were viewed after leaving Rekorra.
- Application-defined Sumo search expressions require careful handling of record-derived data.

## Planned follow-up

0001.6 provider-neutral Context References and 0001.7 Jira Remote Issue Linking before Activity.

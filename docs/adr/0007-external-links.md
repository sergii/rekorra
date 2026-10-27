# ADR 0007 - Provider-aware external links

Status: Accepted for Step 0001.5

## Decision

External Links are a resource capability, not an observability engine. Rekorra renders links after **record visibility** and a separate **link policy** succeed. URL building happens server-side. No provider API call, JavaScript, new tables or credential exchange is required.

A provider has a stable snake_case identifier. The Ruby classes implementing it follow Ruby CamelCase conventions. Current implementations are `:url` (fixed HTTPS base URL, static path, scalar query params) and `:sumo_logic` (official log search deep link).

## Security boundaries

- An external link needs an explicit `authorize:` action. No implicit access based on `show?`.
- Allowed hosts are configured by the host application and HTTPS-only.
- No user-controlled scheme, host, credentials, protocol-relative path or raw query-string concatenation.
- Query parameters are URL encoded. Domain-specific query expressions must still safely handle record-derived values.
- A link uses `rel="noopener noreferrer"` and `referrerpolicy="no-referrer"`.
- External providers perform their own login, SSO, tenancy and permission checks.
- Avoid customer emails, access tokens or other PII in URL query parameters.
- Clicking a link proves navigation intent, **not** that the user subsequently viewed provider data.

## API example

```ruby
external_link :issues, label: "Find related issues", provider: :url,
  base_url: "https://github.com",
  path: "/sergii/rekorra/issues",
  params: ->(order) { { q: "order_id:#{Integer(order.id)}" } },
  authorize: :view_issues?
```

Future providers can be registered behind this same interface. A Jira API integration is a separate capability from generating a Jira deep link.

## Rejected

- Fetching observability data inside the generic view renderer.
- JavaScript-only navigation.
- Assuming Rekorra's authorization grants Datadog/Jira/Grafana permissions.
- Arbitrary unvalidated URL strings from record fields.

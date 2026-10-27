# ADR 0008 - Context references are provider-neutral

Status: Partially accepted and implemented in Step 0001.6; EvidenceRef and persistent relationships remain proposed.

## Naming

Ruby public classes can be `Rekorra::ContextRef`, `Rekorra::ExternalRef`, and `Rekorra::EvidenceRef`. CamelCase is a Ruby **class naming convention**, not a Jira-specific issue convention.

A provider is configured with snake_case symbols such as `:jira`, `:github_issues`, `:intercom`, `:datadog`, `:sumo_logic`, or `:grafana`. Each provider maps its own vocabulary (issue, ticket, conversation, event, trace, log search) to a common reference interface. Do **not** force every provider to use `issue_key`, `ticket_id` or the term "track".

## Implemented value objects (Ruby API)

```ruby
ContextRef.new(
  application: "billing", environment: "production",
  tenant: "acme", resource: "orders", id: "10582"
)

ExternalRef.new(
  provider: :jira, instance: "acme.atlassian.net",
  kind: :issue, id: "10024", display_key: "BILL-482"
)

ExternalRef.new(
  provider: :github_issues, instance: "sergii/rekorra",
  kind: :issue, id: "314"
)

ExternalRef.new(
  provider: :datadog, instance: "us1", kind: :trace,
  id: "4bf92f3577b34da6a3ce929d0e0e4736"
)
```

The `context do` DSL supports `record` and `external` declarations. Resolving an internal reference requires an authorized source record, a registered resource, a tenant-scoped ActiveRecord relation and permission for the target. External references require their own policy and do not automatically fetch external data.

Identity must include the source application/instance and environment. A record ID alone is insufficient; staging and production orders may use the same number.

## Relationship provenance

Explicit link (human or trusted structured identifier), derived link (verified relationship), suggested link (heuristic or AI). Store origin, observed time and evidence; never silently upgrade a suggestion to confirmed.

## Jira direction

Jira Cloud provides Remote Issue Links (`POST /rest/api/3/issue/{issueIdOrKey}/remotelink`) with stable `globalId`. The future Jira adapter can create bidirectional links without a Jira UI plugin, when credentials and rights are configured.

Reference: https://developer.atlassian.com/cloud/jira/platform/rest/v3/api-group-issue-remote-links/

## Security

Resolution must enforce tenant scope and policies for **each** referenced record. Reading a Jira ticket must not grant read access to customer or payment records.

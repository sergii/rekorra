# ADR 0006 - Resource DSL and rendering boundaries

Status: Accepted for prototype

Resource DSL declares models, index/show/form fields, associations, search columns, and callable field renderers. It must not replace Rails, ActiveRecord, or host domain services.

The host provides explicit auth, policy and ActiveRecord::Relation scope adapters. All lookup, association, and assignment paths use them.

Strings returned by custom renderers are escaped through ERB, and trusted SafeBuffer is developer-controlled. No custom frontend runtime or arbitrary SQL DSL is included.

Step 0006 added explicit field-level read/write policies and bounded, scoped belongs_to lookup; see [ADR 0017](0017-resource-field-policies.md). Custom components, richer types and Pundit integration remain future work.

# Step 0006.3 — Rails Enum Fields

Status: Ruby 3.3/3.4 integration CI green; manual UI QA pending.

The Resource DSL supports `field :state, as: :enum` in forms. It validates that the corresponding column is a real model-defined ActiveRecord enum, renders a native select with the exact declared keys, and rejects forged unknown values on POST/PATCH **before assignment** (HTTP 403).

Demo `CaseRecord` and the `:cases` resource use `open/reviewing/closed`. The existing Order.status stays free-form so Activity/PaperTrail behavior is unchanged.

No additional runtime gem, hardcoded application enum list or JavaScript is required. Custom labels/transitions, nullable semantics beyond normal model validation, and specialized widgets remain future work. [CI evidence](https://github.com/sergii/rekorra/actions/runs/40612793162).

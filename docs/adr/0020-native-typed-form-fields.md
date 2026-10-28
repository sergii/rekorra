# ADR 0020 — Native Rails typed forms and strict structured input

Status: Accepted for Step 0006.4; automated integration tests green.

Determine form controls from host model ActiveRecord column metadata rather than a parallel type DSL. Keep explicit enum and belongs_to selectors as higher-priority controls.

Use the Forms::Control object to identify the widget and validate structured boolean, integer, decimal, date and datetime values. Deny malformed or non-scalar input before ActiveRecord attribute assignment; continue relying on the host for model validation, tenant scope and authorization.

Use native HTML controls with no mandatory client runtime. Rails form helpers supply hidden checkbox false values. Timezone, monetary semantics and business number limits remain with the host. Custom widgets, attachment uploads and multi-selection will require separate contracts.
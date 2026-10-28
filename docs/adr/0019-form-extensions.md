# ADR 0019 — Native-first association lookup and model-defined enum widgets

Status: Accepted; integration and Chrome CI green.

Keep the bounded, tenant-scoped native GET association lookup as the fallback. Optional packaged JavaScript fetches the existing authorized Rails HTML and replaces only the target select options; it preserves unsaved form state and selected related record. No new unscoped search endpoint. All foreign keys are reauthorized on mutation.

For enum form fields use the model's defined_enums allowlist rather than arbitrary user parameters or hardcoded Rekorra choices. Validate the DSL and all submitted values before assigning attributes. The demo enum exists on CaseRecord only, without mutating older Order contracts.

Without JS, lookup reloads the form and can discard unsaved fields. Manual accessibility testing remains a release gate.

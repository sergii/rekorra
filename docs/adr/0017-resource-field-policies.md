# ADR 0017 — Resource field authorization and bounded relation lookup

Status: Accepted; Step 0006 automated Ruby and Chrome CI verified. Manual device QA pending.

## Decision

Declare field read/write policies at the Resource class level instead of repeating them independently in Index, Show and Form sections. Evaluate them against the host-provided \`authorize_with(actor, subject, action)\` callback at model/class and individual-record boundaries. A protected field is never mutable merely because the browser sends it in a forged request.

Index filters, sort choices and search columns that have a read restriction must be excluded or rejected for an actor denied at class scope; record-level display access still checks each row before rendering. Host SQL scoping remains indispensable for row-level security and for avoiding query-based inference.

A native GET association lookup reads from host \`scope_with\` and checks related \`:show?\` permissions. It applies a bounded LIKE search and a 50-result cap, plus a pinned current selection. A submitted belongs_to ID must still pass the scoped-ID validation independent of what appeared in HTML.

## Tradeoffs

This generic field-policy contract does not install Pundit or modify a host's existing policies. A real application must ensure the policy for protected columns does not conflict with separately available Activity, exports, custom renderers or unprotected search endpoints. Whole-page GET association search does not preserve unsaved draft changes; a progressive enhancement may address that separately.

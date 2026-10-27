# ADR 0002 - Server-rendered UI and packaged assets

Status: Accepted (prototype)

## Decision
ERB, Rails controllers and standalone packaged CSS. JavaScript is optional. No React/Vue, npm or Node requirement in the host.

## Why
A predictable HTML fallback is useful for admin and support workflows. First prove Propshaft integration and CSS scoping.

## Follow-up
Test Propshaft fingerprinting, Turbo/Stimulus coexistence and Sprockets separately. Add Stimulus only for widgets that need it. WebAssembly is not required for CRUD.

# ADR 0027 - Opt-in host-owned Importmap and enforced CSP

Status: Proposed pending PR #26 full CI.

## Decision

The Rekorra Engine renders its own layout but does **not** require Turbo, Stimulus or Importmap. A host that installs `importmap-rails` and provides its own `config/importmap.rb` / `app/javascript/application.js` may set `Rekorra.configuration.importmap_enabled = true` to include `javascript_importmap_tags` in the Rekorra layout. Default is false.

Do not hard-code `Rails.env.test?` or a test-only environment variable into the public engine layout. The host configures the integration for all environments. An enabled importmap without the necessary host helper fails visibly rather than quietly doing nothing.

The independent Chrome E2E instantiates a new app outside the checkout, tests Propshaft and Sprockets separately, uses actual host-owned models, runs browser navigation/form/association workflows, and verifies nonce-based enforced CSP headers plus actual HTTP asset responses.

## Tradeoffs and deferred checks

An opt-in flag avoids mandatory JavaScript libraries for SSR consumers, but hosts must provide Importmap and assets correctly. CSP nonces are supplied by Rails host configuration; Rekorra must not weaken host CSP with unsafe-inline. The test runs in a locally served isolated test host; verify CDN caching and any additional CSP/CDN/middleware combinations with the actual deployment.

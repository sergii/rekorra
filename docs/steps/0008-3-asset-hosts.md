# Step 0008.3 - Installed Rails asset host compatibility

Status: PR #21 CI passed ([CI run 40678405046](https://github.com/sergii/rekorra/actions/runs/40678405046)); post-merge CI pending.

## Purpose

Validate Rekorra as a separately installed gem in a Rails host using Propshaft or Sprockets and in a host also loading Turbo/Stimulus railties.

## Acceptance

- [x] Installed Propshaft host mounts /backoffice and serves three Rekorra CSS/JS assets
- [x] Installed Sprockets host mounts /backoffice and serves the same assets
- [x] Propshaft + Turbo/Stimulus host boots and serves assets
- [x] Sprockets + Turbo/Stimulus host boots and serves assets
- [x] Chrome verifies Index loading-state cleanup for turbo:before-cache and turbo:load
- [x] Existing 8-job CI remains green, including four Ruby/Rails combinations, PostgreSQL and MySQL
- [ ] Post-merge main CI remains green

## Implementation

The CI package job builds and installs Rekorra into a separate gem directory. Each scenario runs in an isolated temporary host directory and Ruby process. Sprockets hosts declare their own asset manifest. The smoke follows the layout-generated asset URLs with Rack and checks HTTP 200 plus actual CSS/JavaScript content markers. No production runtime dependency on Sprockets, Propshaft, importmap, Turbo or Stimulus is added.

## Boundaries

A loaded Turbo/Stimulus Railtie and successful asset response do not prove a real Turbo navigation or Stimulus controller attachment in an external browser. Production asset precompilation, CSP scenarios, mobile Safari, screen readers and full hosted Hotwire browser tests remain open. The optional Rekorra JavaScript retains the native HTML fallback.

## Verified evidence

[CI run 40678405046](https://github.com/sergii/rekorra/actions/runs/40678405046): 8 of 8 jobs passed. Standalone installed-gem job reports successful asset responses for all four host stacks, while Chrome tests and Rails/Ruby/database compatibility tests also pass. Main post-merge result remains a separate final gate.

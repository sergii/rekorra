# Step 0008.5 - Production assets and Hotwire browser compatibility

Status: Phase 1 merged in PR #23. Phase 2 demo-host Chrome merged in PR #24. External installed-gem browser/CSP PR #26 has dedicated green Propshaft/Sprockets jobs; final PR and post-merge CI pending.

## Acceptance

- [x] Independently installed gem, production Propshaft and Sprockets assets:precompile with fingerprinted CSS/JavaScript (PR #23)
- [x] Real Chrome Turbo Drive + Stimulus demo-host navigation, pagination and browser back (PR #24)
- [x] Real installed-gem **external Rails host** Chrome acceptance with Propshaft (PR #26 CI job passed)
- [x] Same installed-gem external host acceptance with Sprockets (PR #26 CI job passed)
- [x] External-host Turbo navigation and history without replacing JavaScript document
- [x] External-host record creation and tenant-scoped association search preserving unsaved form draft
- [x] External-host Stimulus controller connection
- [x] Enforced nonce-based Content-Security-Policy and actual served Rekorra CSS/JS HTTP 200
- [ ] All PR jobs and post-merge main CI green
- [ ] Production reverse-proxy/CDN/cache headers, browser-specific Safari/VoiceOver QA and manual review

## Implementation

`test/packaging/external_browser.rb` runs from a new temporary directory, without Bundler's source checkout, against the *built and installed* Rekorra gem. It creates host-owned SQLite models/resources/authorization, own importmap entries and JavaScript controllers. Chrome via Capybara and Selenium reaches a real Puma HTTP server. The harness verifies physical host asset URLs over HTTP as well as Turbo and Stimulus behavior.

The host enables `Rekorra.configuration.importmap_enabled = true` explicitly. This is a new optional engine configuration, available outside test mode. The host provides `importmap-rails`, pins, `application.js` and Turbo/Stimulus; Rekorra does not require them as runtime dependencies. Disabled is the default.

The test host enforces CSP with `script-src 'self'` plus per-request nonce and no `unsafe-inline`. The test inspects the actual CSP HTTP header and proves Turbo/Stimulus execute successfully under the policy. The host also verifies scoped record creation after a JavaScript-assisted association search.

## Limits

The CSP test is a real enforced policy in a **test-environment** independent Rails host. It is not evidence that a deployed production system has the same nginx/CDN/reverse-proxy policy. The production asset compilation job separately checks fingerprinted physical output; the external browser test checks HTTP serving in test mode, not deployed fingerprinted assets. Actual deployment-specific CSP, precompiled asset delivery and cache invalidation require deployment QA. Worker reliability issue #25 remains separate.

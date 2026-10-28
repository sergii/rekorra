# Step 0008.5 - Production assets and Hotwire browser compatibility

Status: Phase 1 merged in PR #23 with 11/11 post-merge CI. Phase 2 demo-host Turbo/Stimulus Chrome smoke implemented in PR #24; a dedicated Chrome CI run passed, final PR CI/post-merge pending.

## Phase 1 - Real production precompile

- [x] Installed gem compiles three fingerprinted Rekorra CSS and JavaScript assets in Propshaft production host (CI job green)
- [x] Installed gem compiles the same three assets in Sprockets production host (CI job green)
- [x] All other PR CI gates and post-merge main CI green

Both hosts run outside the repository with an installed gem, production Rails environment, host-owned database configuration, and static asset compilation (`config.assets.compile = false`). Sprockets gets a host-owned manifest. The smoke invokes `assets:precompile` and checks actual fingerprinted output files and expected source content, not only engine registration.

## Phase 2 - Chrome demo-host gate and remaining external-host work

- [x] Real Turbo Drive pagination and browser back in opt-in Hotwire demo host (PR #24 Chrome job passed)
- [ ] Real Turbo Drive navigation in a separately installed external Rails host
- [x] Pagination, browser back and transient busy-state cleanup across real Turbo visits
- [ ] Form submissions and association search across Turbo visits in a separately installed host
- [ ] CSP, deployed static asset server and cache validation

## Caveat

Production precompile checks alone do not establish that the host deployed files or that its Turbo/Stimulus JavaScript works. Rekorra still is an early prototype and not approved for sensitive production workloads.

## Phase 2 approach

PR #24 introduces an opt-in importmap/Turbo/Stimulus demo host with a distinct real Chrome test. It asserts Turbo is active and navigates pagination and browser history while keeping loading state safe. This does not yet meet the stricter independent externally installed gem browser gate or production CSP validation.

## Regression isolation

Browser acceptance is deliberately named `test/browser/turbo_browser.rb`, outside the ordinary `*_test.rb` rake discovery. The opt-in dummy Rails host loads `application.js` from importmap and imports real Turbo/Stimulus modules. A probe controller connects in Chrome, and `turbo:load` counters persist through navigation and history restoration. The production engine does not require Hotwire gems.

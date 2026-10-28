# Step 0008.5 - Production assets and Hotwire browser compatibility

Status: Phase 1 implemented in PR #23, CI verification underway. Phase 2 remains pending.

## Phase 1 - Real production precompile

- [x] Installed gem compiles three fingerprinted Rekorra CSS and JavaScript assets in Propshaft production host (CI job green)
- [x] Installed gem compiles the same three assets in Sprockets production host (CI job green)
- [ ] All other PR CI gates and post-merge main CI green

Both hosts run outside the repository with an installed gem, production Rails environment, host-owned database configuration, and static asset compilation (`config.assets.compile = false`). Sprockets gets a host-owned manifest. The smoke invokes `assets:precompile` and checks actual fingerprinted output files and expected source content, not only engine registration.

## Phase 2 - Not yet done

- [ ] Real Turbo Drive navigation in a Chrome session running an independent Rails host
- [ ] Pagination, form changes, association search across Turbo visits, plus back/forward
- [ ] CSP, deployed static asset server and cache validation

## Caveat

Production precompile checks alone do not establish that the host deployed files or that its Turbo/Stimulus JavaScript works. Rekorra still is an early prototype and not approved for sensitive production workloads.

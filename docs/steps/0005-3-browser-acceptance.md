# Step 0005.3 — Real Browser Acceptance

Status: Headless Chrome and Ruby 3.3/3.4 CI green; physical-device, human visual and screen-reader review still pending.

## Goal

Test the *mounted Rails demo* in a real browser rather than only request tests or static markup. Maintain a reproducible acceptance gate for ordinary Resource Index pages.

## Delivered

- Separate GitHub Actions Browser acceptance (Chrome) job, with Chrome, Capybara, Selenium, the real Rails host, SQLite and Redis.
- Six real Chrome scenarios: desktop header sorting + filters; 390 px mobile responsive cards + Next; 320 px narrow viewport; keyboard Enter; keyset navigation + sort reset; and forms with JavaScript disabled.
- Screenshot artifacts for desktop Users, keyset and both mobile sizes, plus automatic failure HTML/screenshot capture.
- Browser-only dependencies in the test Gemfile. None added to the published gem.
- Test-only Basic Authorization via Chrome CDP, and deterministic resetting of mobile emulation and script execution between tests.
- Explicit empty favicon in layout to prevent implicit Chrome /favicon.ico requests from causing unrelated test-mode routing exceptions.

## Evidence

[GitHub Actions run 40609160888](https://github.com/sergii/rekorra/actions/runs/40609160888):

- Chrome: **6 runs, 42 assertions, 0 failures/errors/skips**.
- Ruby 3.3 and Ruby 3.4: **117 runs, 659 assertions, 0 failures/errors/skips** on each version.
- Artifact: **rekorra-browser-acceptance**, images under test/dummy/tmp/screenshots/index-acceptance/.

## Acceptance

- [x] Real Chrome and Rails mounted-engine navigation
- [x] 1280 px desktop, 390 px mobile and 320 px narrow responsive layout
- [x] No page-level horizontal overflow at both tested phone widths
- [x] Native filters, sortable columns and keyboard Enter
- [x] Offset and keyset navigation
- [x] Native GET navigation with JavaScript disabled
- [x] Reproducible CI screenshots and failure HTML artifacts
- [ ] Human visual inspection of screenshots
- [ ] Physical iOS/Android touch-device check
- [ ] VoiceOver, TalkBack or NVDA verification
- [ ] Light/dark contrast and zoom/reflow checks

## Running locally

Prepare the demo test DB and run the browser suite from repo root; requires Chrome and Redis.

    (cd test/dummy && RAILS_ENV=test bundle exec rails db:prepare)
    RAILS_ENV=test REDIS_URL=redis://127.0.0.1:6379/12 bundle exec ruby -Itest test/browser/resource_index_browser.rb

A green Chrome run is **not** human screenshot sign-off and does not substitute for screen-reader, mobile Safari or physical-device tests.

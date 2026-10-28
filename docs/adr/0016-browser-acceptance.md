# ADR 0016 — Reproducible Chrome browser acceptance

Status: Accepted; browser acceptance CI verified in Step 0005.3.

## Decision

Use a separate Rails SystemTestCase / Capybara / Selenium + Google Chrome CI job to test the real mounted Rails demo. Keep Capybara and Selenium test-only dependencies rather than mandatory Rekorra runtime dependencies.

Cover native desktop and mobile model Index interaction, keyboard Enter, SQL-scoped records in the browser, keyset navigation and the no-JavaScript fallback. Capture desktop/mobile screenshots as CI artifacts for later human review.

## Isolation

Chrome CDP supplies demo-only HTTP Basic authentication header and device metrics. Every test resets device emulation and script execution so test results are independent of run order.

Add an explicit empty favicon link to prevent implicit browser requests from failing Rails in strict test routing mode. Do not relax the application's exception behavior.

## Limits

Headless browser geometry and scripted interactions are **not** manual visual QA, a screen-reader audit, physical-device or Safari test. These remain open acceptance gates, alongside dark/light and zoom/reflow checks.

# Step 0008.0 — Rails compatibility and installed gem

Status: Merged as PR #18; post-merge CI green. PostgreSQL passed Step 0008.1; MySQL validation is Step 0008.2.

## Scope

- Four integration legs: Ruby 3.3 and 3.4 crossed with Rails 8.0 and 8.1.
- Browser acceptance remains an independent headless Chrome job.
- Build a real distributable Ruby gem, install it into a separate gem directory and boot a minimal Rails host outside the repository.
- Verify that views, CSS, JavaScript and routes are present in the installed package and that GET /backoffice returns HTTP 200.
- Keep published gem dependencies unchanged.

## Acceptance

- [x] Rails 8.0 + Ruby 3.3 integration
- [x] Rails 8.0 + Ruby 3.4 integration
- [x] Rails 8.1 + Ruby 3.3 integration
- [x] Rails 8.1 + Ruby 3.4 integration
- [x] Default Rails + Chrome acceptance
- [x] Installed gem HTTP smoke
- [x] Post-merge CI green

Post-merge evidence: [run 40667341789](https://github.com/sergii/rekorra/actions/runs/40667341789). Rails compatibility and installed package gates passed.

## Still open

No production-ready declaration. PostgreSQL 16 passed Step 0008.1, while MySQL 8.4 is pending Step 0008.2. Sprockets-only hosts, existing Turbo/Stimulus host, Ruby 3.2, worker E2E, manual accessibility and mobile Safari, and production security audits remain separate gates. Rails 7 support is not claimed.

## CI evidence

[GitHub Actions run 40666858122](https://github.com/sergii/rekorra/actions/runs/40666858122) passed all six jobs: four Ruby/Rails combinations, each 154 tests / 925 assertions; Chrome 8 tests / 58 assertions; installed rekorra-0.1.0.pre package in an independent Rails host with GET /backoffice returning HTTP 200 and required packaged assets present. No test failures, errors or skips.

# Step 0008.0 — Rails compatibility and installed gem

Status: Implemented on feature branch; package smoke and final CI verification pending.

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
- [ ] Installed gem HTTP smoke
- [ ] Post-merge CI green

## Still open

No production-ready declaration. PostgreSQL/MySQL, Sprockets-only hosts, existing Turbo/Stimulus host, Ruby 3.2, worker E2E, manual accessibility and mobile Safari, and production security audits remain separate gates. Rails 7 support is not claimed.

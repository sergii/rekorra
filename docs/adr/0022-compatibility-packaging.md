# ADR 0022 — Version compatibility and isolated gem packaging

Status: Accepted and tested in CI run 40666858122; post-merge verification pending.

## Decision

Exercise the gem against Rails 8.0 and Rails 8.1, on Ruby 3.3 and 3.4, with separate Bundler resolutions. Select the Rails minor version only in the repository Gemfile through a CI-only environment variable, never in published Rekorra dependencies.

Independently build the distributable .gem, install it outside the checkout, then boot a minimal Rails host that loads the installed Rekorra package, mounts the engine and makes an HTTP request. Assert required engine CSS, JavaScript, templates and routes are included in the installed artifact.

## Rationale

Source-checkout integration tests cannot prove that the installed gem includes all runtime assets. A single modern Rails resolution cannot prove compatibility with older allowed minor versions. These tests cover separate failure classes and should stay separate CI jobs.

## Not covered

Passing this gate does not establish support for Rails 7 or guarantee PostgreSQL/MySQL performance, Sprockets, Turbo, deployment packaging, Rails production hardening or accessibility. The project remains a technical prototype.

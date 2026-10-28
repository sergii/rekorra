# ADR 0025 - Pipeline-neutral installed Engine assets

Status: Proposed pending PR #21 CI.

## Context

The installed gem packaging smoke originally booted only Propshaft and inspected the existence of packaged asset files. This did not prove that CSS and JavaScript were actually served, that Sprockets could resolve the engine namespace, or that optional Turbo/Stimulus railties could coexist.

## Decision

Keep engine-namespaced asset links and vanilla progressive JavaScript. Add four standalone host smoke variants: Propshaft, Sprockets, and each with Turbo/Stimulus. A normal Sprockets host owns a manifest. Every variant must boot the installed engine, resolve layout URLs and return HTTP 200 with correct body content for its CSS and both JavaScript assets.

Clear Index loading indicators on turbo:before-cache and turbo:load in addition to browser pageshow. Test lifecycle cleanup in real Chrome, without requiring Turbo in the Rekorra gem.

## Deferred

Real Turbo Drive and Stimulus controller E2E in an external browser, fingerprinted production asset builds, CSP policies and other production deployment variations. Passing these smoke tests does not claim complete Turbo/Stimulus support.

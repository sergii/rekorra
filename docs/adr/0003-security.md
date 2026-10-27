# ADR 0003 - Fail-closed security

Status: Accepted (prototype)

## Decision
Require explicit authentication, authorization and relation-scoping adapters. Reject requests if authentication is absent. Never assume that an authenticated actor may read or mutate a record.

## Why
An admin engine may expose sensitive business records. Authorization must cover root access, list, record and related-record views and writes.

## Risks / next steps
Security is not complete until per-resource authorization, tenant scoping, CSRF, association visibility and mutation tests pass. Demo HTTP Basic is not a production authentication recommendation.

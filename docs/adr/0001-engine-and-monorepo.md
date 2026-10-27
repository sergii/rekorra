# ADR 0001 - Monorepo and mounted Rails Engine

Status: Accepted (prototype)

## Decision
Start with one gem repository. Package a namespaced `Rekorra::Engine` and keep a real Rails host application in `test/dummy`. Mount under `/backoffice`.

## Why
Every vertical slice is implemented and tested in both the demo domain and engine without cross-repository version coordination.

## Alternatives
Two repositories (gem and sample host app) or multiple gems. Reconsider after the API and CI stabilize.

## Constraints
Host application owns database, users, authentication, authorization and domain rules. Rekorra does not mutate host schema by default.

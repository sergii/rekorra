# ADR 0018 — Pundit as an optional security adapter

Status: Accepted; integration CI green.

Retain Rekorra's host-defined authentication, authorize_with and scope_with contracts. Supply optional Pundit-based call objects for policy predicates and a separate SQL-level policy scope. Missing policy predicates deny; a missing or invalid relation scope raises ConfigurationError. No silent Model.all fallback.

The Pundit dependency belongs to the host; Rekorra's published gem does not require it. A host still explicitly authorizes global :access? and implements its policy classes and scopes.

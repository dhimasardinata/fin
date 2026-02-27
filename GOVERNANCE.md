# Governance

## Scope

This document governs language, compiler, runtime, package, and release decisions for Fin.

## Proposal System

- Canonical proposal ID: `FIP-####`.
- Canonical proposal URI: `fin://fip/FIP-####`.
- Canonical path: `fips/FIP-####-<slug>.md`.

## Proposal Lifecycle

Allowed statuses:

1. `Draft`
2. `Review`
3. `Accepted`
4. `Scheduled`
5. `InProgress`
6. `Implemented`
7. `Released`
8. `Deferred`
9. `Rejected`

Status transitions are only valid when the proposal metadata `status` and changelog are updated in the same pull request.

## Decision Rules

- Any feature or behavior change must reference a FIP.
- Merge gate: feature pull requests must link a FIP in status `Accepted` or `Scheduled`.
- Breaking changes additionally require compatibility analysis per `COMPATIBILITY.md`.

## Branch and Release Policy

- `main`: stable branch.
- `next`: integration branch for scheduled work.
- Releases are tagged from `main` and must include reproducibility and provenance artifacts.

## Security and Provenance

- Bootstrap trust uses audited seed artifacts in `seed/`.
- Seed hash must be immutable per release line.
- CI must block any external compiler/assembler/linker invocation in normal build paths.

## Ownership

Initial maintainer and approver authority is repository owner until governance delegation is ratified by a dedicated FIP.

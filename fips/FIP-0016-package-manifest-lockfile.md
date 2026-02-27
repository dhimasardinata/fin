# FIP-0016: Package Manifest and Lockfile

- id: FIP-0016
- address: fin://fip/FIP-0016
- status: Draft
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0015"]
- target_release: M6
- discussion: TBD
- implementation: []
- acceptance:
  - Deterministic resolution and lockfile update tests pass.

## Summary

Defines fin.toml and fin.lock schema and behavior.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Initial design details are tracked in the corresponding spec and architecture documents. Concrete implementation deltas must be appended to this section before status changes to InProgress.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Acceptance criteria listed above are normative; CI coverage for this proposal must be linked in implementation once available.

# FIP-0020: CI Gate: External Toolchain Prohibited

- id: FIP-0020
- address: fin://fip/FIP-0020
- status: Scheduled
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0002", "FIP-0018"]
- target_release: M0
- discussion: TBD
- implementation: []
- acceptance:
  - CI job fails on disallowed command invocation patterns.

## Summary

Defines mandatory CI checks that block external toolchain usage.

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

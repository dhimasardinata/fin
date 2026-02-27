# FIP-0013: Fin Object Format (finobj)

- id: FIP-0013
- address: fin://fip/FIP-0013
- status: Draft
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0010"]
- target_release: M5
- discussion: TBD
- implementation: []
- acceptance:
  - Object reader/writer round-trip tests pass.

## Summary

Defines relocatable object format for multi-unit builds.

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

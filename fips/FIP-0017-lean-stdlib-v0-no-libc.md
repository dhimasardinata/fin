# FIP-0017: Lean Stdlib v0 (No-libc)

- id: FIP-0017
- address: fin://fip/FIP-0017
- status: Draft
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0009", "FIP-0012"]
- target_release: M6
- discussion: TBD
- implementation: []
- acceptance:
  - Stdlib API conformance and runtime ABI tests pass.

## Summary

Defines portable minimal standard library surface and constraints.

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

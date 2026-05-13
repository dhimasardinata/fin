# FIP-0001: Language Charter and Philosophy

- id: FIP-0001
- address: fin://fip/FIP-0001
- status: Implemented
- authors: @fin-maintainers
- created: 2026-02-27
- requires: []
- target_release: M0
- discussion: TBD
- implementation:
  - docs/charter.md
  - README.md
  - SPEC.md
  - GOVERNANCE.md
  - tests/reproducibility/verify_charter_policy_gate.ps1
  - tests/run_stage0_suite.ps1
- acceptance:
  - Charter is merged and referenced by spec and governance docs.

## Summary

Defines Fin goals, non-goals, and product philosophy.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current implementation delta:

1. `docs/charter.md` is the canonical project charter for goals, non-goals, product philosophy, and non-negotiable constraints.
2. `README.md` references the charter from the project goals section.
3. `SPEC.md` references the charter from the design principles section.
4. `GOVERNANCE.md` references the charter as the alignment source for governance changes.
5. `tests/reproducibility/verify_charter_policy_gate.ps1` statically verifies the charter sections and references.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

FIP-0001 is foundational policy. Future changes to goals, non-goals, product philosophy, or non-negotiable constraints must update the charter, FIP, and references in the same change.

## Test Plan

Current checks:

1. `tests/reproducibility/verify_charter_policy_gate.ps1` validates the canonical charter sections, README/SPEC/GOVERNANCE references, FIP implementation links, and index status.
2. `tests/run_stage0_suite.ps1` runs the charter policy gate in the aggregate stage0 suite.

Acceptance criteria listed above are now enforced by CI.

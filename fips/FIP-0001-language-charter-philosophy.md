# FIP-0001: Language Charter and Philosophy

- id: FIP-0001
- address: fin://fip/FIP-0001
- status: Accepted
- authors: @fin-maintainers
- created: 2026-02-27
- requires: []
- target_release: M0
- discussion: TBD
- implementation:
  - README.md
  - SPEC.md
  - GOVERNANCE.md
  - docs/architecture.md
  - ci/verify_fip_metadata.ps1
- acceptance:
  - Charter is merged and referenced by spec and governance docs.

## Summary

Defines Fin goals, non-goals, and product philosophy.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current charter implementation:

1. `README.md` publishes the project goals, current status, and non-negotiable constraints.
2. `SPEC.md` keeps the language design principles visible as the living specification baseline.
3. `GOVERNANCE.md` references this charter as the decision-making basis for language, compiler, runtime, package, and release changes.
4. `docs/architecture.md` records the staged independent-toolchain architecture used to keep the charter actionable.
5. `ci/verify_fip_metadata.ps1` keeps FIP metadata and index references synchronized in CI.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `ci/verify_fip_metadata.ps1` validates FIP metadata/index consistency.
2. `cmd/fin/fin.ps1 doctor` and GitHub Actions both run the metadata verifier.

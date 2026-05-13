# FIP-0019: Compatibility and Editions Policy

- id: FIP-0019
- address: fin://fip/FIP-0019
- status: Implemented
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0002"]
- target_release: M0
- discussion: TBD
- implementation:
  - COMPATIBILITY.md
  - GOVERNANCE.md
  - docs/release-provenance.md
  - .github/PULL_REQUEST_TEMPLATE.md
  - tests/reproducibility/verify_compatibility_policy.ps1
  - tests/run_stage0_suite.ps1
- acceptance:
  - Compatibility policy is published and referenced by release process.

## Summary

Defines compatibility guarantees and edition migration rules.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current implementation delta:

1. `COMPATIBILITY.md` publishes the versioning, stability bucket, breaking-change, edition, and release reproducibility policy.
2. `GOVERNANCE.md` requires compatibility analysis for breaking changes.
3. `docs/release-provenance.md` requires release compatibility notes derived from `COMPATIBILITY.md`.
4. `.github/PULL_REQUEST_TEMPLATE.md` prompts contributors to document compatibility impact.
5. `tests/reproducibility/verify_compatibility_policy.ps1` gates the policy, governance, release, PR-template, and FIP implementation links.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

This FIP defines the compatibility policy. Changes to the policy itself must be
reviewed as governance-affecting changes and keep release/proposal references in
sync.

## Test Plan

Current checks:

1. `tests/reproducibility/verify_compatibility_policy.ps1` validates the published policy sections, release-process reference, governance breaking-change rule, PR compatibility checklist, and FIP implementation linkage.
2. `tests/run_stage0_suite.ps1` includes the compatibility policy check in `fin test`.

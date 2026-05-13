# FIP-0002: Governance and FIP Process

- id: FIP-0002
- address: fin://fip/FIP-0002
- status: Accepted
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0001"]
- target_release: M0
- discussion: TBD
- implementation:
  - GOVERNANCE.md
  - fips/README.md
  - fips/INDEX.md
  - .github/PULL_REQUEST_TEMPLATE.md
  - .github/labels.json
  - .github/workflows/ci.yml
  - ci/check_fip_link.ps1
  - ci/verify_fip_metadata.ps1
  - cmd/fin/fin.ps1
  - tests/reproducibility/verify_fip_metadata_policy_gate.ps1
  - tests/reproducibility/verify_fip_policy_gate.ps1
  - tests/run_stage0_suite.ps1
- acceptance:
  - Lifecycle and merge checks are documented and enforced in CI.

## Summary

Defines proposal lifecycle, decision authority, and merge rules.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current governance implementation:

1. `GOVERNANCE.md` defines canonical FIP IDs, addresses, lifecycle statuses, branch policy, release policy, and the feature-change merge gate.
2. `fips/INDEX.md` publishes the current FIP title/status/address table.
3. `.github/labels.json` defines status labels for every governance lifecycle state.
4. `.github/PULL_REQUEST_TEMPLATE.md` requires contributors to declare the related FIP.
5. `ci/check_fip_link.ps1` blocks feature-critical pull requests when the title/body does not link an existing FIP in an eligible status (`Accepted`, `Scheduled`, `InProgress`, `Implemented`, or `Released`).
6. `ci/verify_fip_metadata.ps1` verifies FIP filename/header/metadata consistency, non-empty authors, canonical `created` dates, allowed lifecycle statuses, non-empty acceptance criteria, `requires` references, implementation-path existence, required sections, implemented/released discussion and compatibility completion, index synchronization, status-label coverage, and CI/doctor wiring.
7. `cmd/fin/fin.ps1 doctor` and GitHub Actions both execute the metadata verifier.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `ci/verify_fip_metadata.ps1` validates lifecycle metadata, non-empty authors, canonical `created` dates, non-empty acceptance criteria, index consistency, status-label coverage, `requires` references, implementation-path existence, implemented/released discussion and compatibility completion, and CI/doctor wiring.
2. `tests/reproducibility/verify_fip_metadata_policy_gate.ps1` validates metadata-policy failures for missing author metadata, malformed/invalid `created` dates, empty acceptance criteria, missing/unsafe implementation paths, invalid/unknown `requires` entries, accepted FIPs with empty implementation lists, and implemented FIPs that still carry discussion or compatibility placeholders, while keeping draft-empty implementation allowed.
3. `tests/reproducibility/verify_fip_policy_gate.ps1` validates feature-critical pull request checks for missing links, unknown FIPs, ineligible review FIPs, and eligible accepted/in-progress/implemented FIPs.
4. `ci/check_fip_link.ps1` validates feature-critical pull requests have an explicit eligible FIP link.
5. GitHub Actions runs both CI checks in the policy job, and `tests/run_stage0_suite.ps1` runs the policy self-checks.
6. `cmd/fin/fin.ps1 doctor` runs the metadata verifier locally.

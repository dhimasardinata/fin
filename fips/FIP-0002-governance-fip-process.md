# FIP-0002: Governance and FIP Process

- id: FIP-0002
- address: fin://fip/FIP-0002
- status: Implemented
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0001"]
- target_release: M0
- discussion: TBD
- implementation:
  - GOVERNANCE.md
  - CONTRIBUTING.md
  - fips/README.md
  - fips/TEMPLATE.md
  - fips/INDEX.md
  - .github/PULL_REQUEST_TEMPLATE.md
  - .github/labels.json
  - .github/workflows/ci.yml
  - ci/check_fip_link.ps1
  - tests/reproducibility/verify_fip_link_policy_gate.ps1
  - tests/run_stage0_suite.ps1
- acceptance:
  - Lifecycle and merge checks are documented and enforced in CI.

## Summary

Defines proposal lifecycle, decision authority, and merge rules.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current implementation delta:

1. `GOVERNANCE.md`, `CONTRIBUTING.md`, and `fips/README.md` define FIP identity, lifecycle states, merge/link rules, and the same-PR implementation/status-transition allowance.
2. `fips/TEMPLATE.md` defines required FIP metadata and sections for new proposals.
3. `fips/INDEX.md` provides the canonical status index for current FIPs.
4. `.github/labels.json` maps status labels to FIP lifecycle states.
5. `.github/PULL_REQUEST_TEMPLATE.md` prompts linked proposal, test, compatibility, and reproducibility impact entries.
6. `.github/workflows/ci.yml` runs `ci/check_fip_link.ps1` for pull requests.
7. `ci/check_fip_link.ps1` enforces that feature-critical pull requests link an existing FIP in `Accepted` or `Scheduled`, or link the same FIP being transitioned to `InProgress`, `Implemented`, or `Released` in that pull request.
8. `tests/reproducibility/verify_fip_link_policy_gate.ps1` self-checks the link gate with synthetic FIP roots and positive/negative status cases.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

This change tightens governance checks for feature-critical pull requests. Existing implementation/status-transition workflows remain supported when the linked FIP file is changed in the same pull request.

## Test Plan

Current checks:

1. `ci/check_fip_link.ps1` enforces linked FIP existence and acceptable status for feature-critical pull requests.
2. `tests/reproducibility/verify_fip_link_policy_gate.ps1` validates no-feature bypass, missing-link failure, unknown-FIP failure, Draft/Rejected rejection, Accepted/Scheduled success, and same-PR InProgress/Implemented transition success.
3. `.github/workflows/ci.yml` runs the FIP link gate after collecting changed files on pull requests.

Acceptance criteria listed above are now enforced by CI.

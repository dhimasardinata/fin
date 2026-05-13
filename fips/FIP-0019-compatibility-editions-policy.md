# FIP-0019: Compatibility and Editions Policy

- id: FIP-0019
- address: fin://fip/FIP-0019
- status: Accepted
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0002"]
- target_release: M0
- discussion: TBD
- implementation:
  - COMPATIBILITY.md
  - GOVERNANCE.md
  - .github/PULL_REQUEST_TEMPLATE.md
  - .github/workflows/release.yml
  - docs/release-provenance.md
  - ci/verify_fip_metadata.ps1
- acceptance:
  - Compatibility policy is published and referenced by release process.

## Summary

Defines compatibility guarantees and edition migration rules.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current compatibility implementation:

1. `COMPATIBILITY.md` defines versioning, stability buckets, breaking-change rules, edition policy, and release reproducibility requirements.
2. `GOVERNANCE.md` requires compatibility analysis for breaking changes.
3. `.github/PULL_REQUEST_TEMPLATE.md` includes a compatibility-impact checklist item.
4. `.github/workflows/release.yml` publishes release metadata, including seed and reproducibility references.
5. `docs/release-provenance.md` links compatibility notes to release provenance expectations.
6. `ci/verify_fip_metadata.ps1` keeps FIP status/index references synchronized in CI.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `ci/verify_fip_metadata.ps1` validates FIP metadata/index consistency.
2. `.github/workflows/release.yml` requires release metadata to be produced for tagged releases.
3. Pull request template review requires compatibility impact to be documented.

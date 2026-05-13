# FIP-0003: Bootstrap Trust Model (Seed Binary)

- id: FIP-0003
- address: fin://fip/FIP-0003
- status: Accepted
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0001", "FIP-0002"]
- target_release: M0
- discussion: TBD
- implementation:
  - seed/README.md
  - seed/manifest.toml
  - seed/SHA256SUMS
  - ci/verify_seed_hash.ps1
  - .github/workflows/ci.yml
  - .github/workflows/release.yml
  - docs/bootstrap.md
  - tests/bootstrap/verify_stage0_closure.ps1
  - seed/stage0-closure-baseline.txt
- acceptance:
  - Seed manifest schema and verification scripts exist and pass checks.

## Summary

Defines audited seed artifact trust anchor and hash policies.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current seed-trust implementation:

1. `seed/README.md` documents the seed artifact policy and review requirements.
2. `seed/manifest.toml` records seed identity, version, artifact path, hash field, format, and immutability policy.
3. `seed/SHA256SUMS` records the expected seed hash placeholder until an audited seed artifact is committed.
4. `ci/verify_seed_hash.ps1` validates seed metadata and supports `-RequireSet` for release-time enforcement.
5. GitHub CI checks seed metadata on every push/PR; the release workflow requires the seed hash to be set.
6. `docs/bootstrap.md`, `tests/bootstrap/verify_stage0_closure.ps1`, and `seed/stage0-closure-baseline.txt` document and validate the current stage0 closure proxy while native seed closure is pending.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `ci/verify_seed_hash.ps1` validates seed metadata in normal CI.
2. `.github/workflows/release.yml` runs `ci/verify_seed_hash.ps1 -RequireSet` for tagged releases.
3. `tests/bootstrap/verify_stage0_closure.ps1 -VerifyBaseline` validates the current stage0 closure proxy against `seed/stage0-closure-baseline.txt`.

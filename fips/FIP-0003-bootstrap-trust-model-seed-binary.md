# FIP-0003: Bootstrap Trust Model (Seed Binary)

- id: FIP-0003
- address: fin://fip/FIP-0003
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0001", "FIP-0002"]
- target_release: M0
- discussion: TBD
- implementation:
  - seed/manifest.toml
  - seed/SHA256SUMS
  - seed/stage0-closure-baseline.txt
  - ci/verify_seed_hash.ps1
  - tests/bootstrap/verify_stage0_closure.ps1
  - tests/reproducibility/verify_seed_hash_policy_gate.ps1
  - tests/run_stage0_suite.ps1
  - .github/workflows/ci.yml
- acceptance:
  - Seed manifest schema and verification scripts exist and pass checks.

## Summary

Defines audited seed artifact trust anchor and hash policies.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current implementation delta:

1. `seed/manifest.toml` records the seed identity, artifact path, declared SHA256 value, artifact format, and review/immutability policy.
2. `seed/SHA256SUMS` records the expected hash entry for the manifest artifact path.
3. The initial repository state permits `UNSET` for the seed hash until the audited seed artifact is committed; `-RequireSet` rejects `UNSET` for release/self-hosting paths.
4. `ci/verify_seed_hash.ps1` validates manifest schema fields, SHA256SUMS entry format, manifest/SHA256SUMS path consistency, duplicate artifact entries, hash-format constraints, optional `-RequireSet` enforcement, and actual artifact hash parity when a concrete seed artifact is present.
5. `.github/workflows/ci.yml` runs the seed metadata verifier in policy before deeper stage0 checks.
6. `tests/bootstrap/verify_stage0_closure.ps1` includes the seed metadata in the stage0 closure witness and can require a concrete seed hash when `-RequireSeedSet` is enabled.
7. `tests/reproducibility/verify_seed_hash_policy_gate.ps1` exercises valid `UNSET`, `-RequireSet` rejection, invalid hash format, manifest/SHA256SUMS mismatch, missing sums path, concrete artifact hash success, and concrete artifact mismatch failure cases.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

FIP-0003 currently tightens metadata validation without changing the committed seed hash value. Release or self-hosting flows that require a concrete audited seed must use `-RequireSet`, and future seed rotation must update the manifest, SHA256SUMS, closure baseline, and release notes in one reviewed change.

## Test Plan

Current checks:

1. `ci/verify_seed_hash.ps1` runs in CI policy against the committed seed metadata.
2. `tests/reproducibility/verify_seed_hash_policy_gate.ps1` self-checks the seed metadata policy behavior with generated manifests, hash files, and concrete artifact bytes.
3. `tests/bootstrap/verify_stage0_closure.ps1` records seed metadata in the closure witness and supports `-RequireSeedSet` for release/self-hosting enforcement.

Acceptance remains InProgress until the audited seed artifact hash is set instead of `UNSET`.

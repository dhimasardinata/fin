# FIP-0011: Self-Hosting Closure Criteria

- id: FIP-0011
- address: fin://fip/FIP-0011
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0003", "FIP-0010"]
- target_release: M3
- discussion: TBD
- implementation:
  - tests/bootstrap/verify_stage0_closure.ps1
  - tests/run_stage0_suite.ps1
  - docs/bootstrap.md
- acceptance:
  - Stage0 proxy closure hash is stable in CI.
  - fin-seed -> finc -> finc closure hash is stable in CI before release status.

## Summary

Defines deterministic bootstrap closure checks and hash criteria.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 closure proxy:

1. Build fixed source input twice through stage0 pipeline (`gen1`, `gen2`).
2. Require `sha256(gen1) == sha256(gen2)`.
3. Compute and record snapshot hashes for:
   - seed metadata files (`seed/manifest.toml`, `seed/SHA256SUMS`)
   - stage0 toolchain control scripts (`cmd/fin/fin.ps1`, stage0 build/parser/emitter scripts)
4. Write closure witness record to `artifacts/closure/stage0-closure-witness.txt`.

This proxy establishes deterministic closure evidence before native self-hosting exists.
Full `fin-seed -> finc -> finc` closure remains the completion requirement for Implemented status.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/bootstrap/verify_stage0_closure.ps1` validates `gen1 == gen2` hash equality and witness output.
2. `tests/run_stage0_suite.ps1` includes closure check in `fin test`.
3. CI executes `cmd/fin/fin.ps1 test --no-doctor` on push/PR.

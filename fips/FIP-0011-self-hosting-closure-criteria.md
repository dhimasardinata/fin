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
  - seed/stage0-closure-baseline.txt
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

1. Build fixed source input twice for each stage0 matrix case:
   - `x86_64-linux-elf` + `direct`
   - `x86_64-linux-elf` + `finobj`
   - `x86_64-windows-pe` + `direct`
   - `x86_64-windows-pe` + `finobj`
2. Require per-case deterministic equality (`sha256(gen1) == sha256(gen2)`).
3. Require direct/finobj parity for each target (Linux and Windows).
4. Compute and record snapshot hashes for:
   - seed metadata files (`seed/manifest.toml`, `seed/SHA256SUMS`)
   - stage0 toolchain control scripts (`cmd/fin/fin.ps1`, stage0 build/parser/emit/finobj/finld scripts)
5. Write closure witness record to `artifacts/closure/stage0-closure-witness.txt`.
6. Compare closure witness keys to committed baseline (`seed/stage0-closure-baseline.txt`) in stage0 test suite with strict keyset validation (missing/mismatch/unexpected key rejection), duplicate-key rejection, and canonical key-order validation.
7. Materialize closure build outputs in a run-scoped workspace under `artifacts/closure` using run-tokenized output basenames to avoid cross-run collisions in both final outputs and stage0 intermediate finobj temp paths.

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

1. `tests/bootstrap/verify_stage0_closure.ps1` validates deterministic `gen1 == gen2` for all stage0 target/pipeline matrix cases, target-level direct/finobj parity, and run-scoped closure workspace isolation.
2. `tests/run_stage0_suite.ps1` includes closure check in `fin test`.
3. Stage0 suite verifies closure witness against committed baseline with strict required-key equality, duplicate-key rejection, and canonical key-order validation.
4. CI executes `cmd/fin/fin.ps1 test --no-doctor` on push/PR.

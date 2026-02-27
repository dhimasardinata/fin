# FIP-0014: Fin Linker (finld)

- id: FIP-0014
- address: fin://fip/FIP-0014
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0013"]
- target_release: M5
- discussion: TBD
- implementation:
  - compiler/finld/stage0/link_finobj_to_elf.ps1
  - compiler/finc/stage0/build_stage0.ps1
  - cmd/fin/fin.ps1
  - tests/integration/verify_finobj_link.ps1
  - tests/integration/verify_build_pipeline_finobj.ps1
  - tests/run_stage0_suite.ps1
- acceptance:
  - Linker suite passes symbol and relocation correctness checks.

## Summary

Defines static linker behavior, symbol resolution, and relocations.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 linker path:

1. Read stage0 finobj payload (`exit_code`) via finobj reader.
2. Emit final Linux ELF through direct emitter path with decoded exit code.
3. Expose `fin build/run --pipeline finobj` to route stage0 compilation through finobj+finld.
4. Optional structure verification after link.

This is a minimal single-object checkpoint before full symbol-resolution and relocation support.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/integration/verify_finobj_link.ps1` validates finobj -> ELF link path and runtime exit behavior.
2. `tests/integration/verify_build_pipeline_finobj.ps1` validates `fin build/run --pipeline finobj` and output parity with direct pipeline.
3. `tests/run_stage0_suite.ps1` includes finld integration checks in `fin test`.

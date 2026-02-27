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

1. Read stage0 finobj metadata payload via finobj reader.
2. Require exactly one entry object (`entry_symbol=main`) and allow additional non-entry objects (`entry_symbol=unit`).
3. Emit final native image through direct emitter path with decoded entry exit code (`x86_64-linux-elf` or `x86_64-windows-pe`).
4. Expose `fin build/run --pipeline finobj` to route stage0 compilation through finobj+finld.
5. Optional structure verification after link.

This is a minimal multi-object checkpoint before full symbol-resolution and relocation support.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/integration/verify_finobj_link.ps1` validates multi-object finobj -> native link path for Linux ELF and Windows PE runtime behavior, including missing/duplicate entry-object rejection.
2. `tests/integration/verify_build_pipeline_finobj.ps1` validates Linux `fin build/run --pipeline finobj` and output parity with direct pipeline.
3. `tests/run_stage0_suite.ps1` includes finld integration checks in `fin test`.

# FIP-0018: Deterministic and Reproducible Builds

- id: FIP-0018
- address: fin://fip/FIP-0018
- status: Implemented
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0003"]
- target_release: M0
- discussion: TBD
- implementation:
  - tests/reproducibility/verify_stage0_reproducibility.ps1
  - tests/run_stage0_suite.ps1
  - .github/workflows/ci.yml
- acceptance:
  - CI reproducibility checks pass across repeated builds.

## Summary

Defines reproducibility controls, inputs, and output hashing rules.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 reproducibility controls:

1. Deterministic direct ELF emitters (`emit_elf_exit0`, `emit_elf_write_exit`).
2. Deterministic stage0 source build (`fin build` for fixed inputs).
3. Deterministic stage0 source build through `finobj+finld` (`fin build --pipeline finobj`) for fixed inputs.
4. Deterministic stage0 Windows target build (`fin build --target x86_64-windows-pe`) for fixed inputs.
5. Deterministic package artifact generation (`fin pkg publish`) for fixed inputs.
6. Deterministic stage0 `finobj` writing (`write_finobj_exit`) for fixed inputs.
7. Deterministic stage0 `finld` linking (`link_finobj_to_elf`) for fixed inputs.
8. Hash-based verification across repeated invocations.

Reproducibility scope is currently single-host CI with stable PowerShell/runtime context.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/reproducibility/verify_stage0_reproducibility.ps1` validates repeated-hash stability for emit/build (direct, `finobj` pipeline, Windows target)/publish/finobj/finld paths.
2. `tests/run_stage0_suite.ps1` includes reproducibility checks as part of `fin test`.
3. CI executes `cmd/fin/fin.ps1 test --no-doctor` on push/PR.

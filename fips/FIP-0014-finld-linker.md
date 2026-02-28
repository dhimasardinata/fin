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
3. Canonicalize object-set metadata deterministically (entry-priority + source identity order) before link evaluation.
4. Reject duplicate object path input and duplicate object identity (`entry_symbol|source_path|source_sha256`).
5. Build stage0 symbol provider table from finobj `provides` + `symbol_values` metadata and reject duplicate symbol providers.
6. Require entry object to provide `main` symbol and reject entry/provider mismatches.
7. Validate finobj `requires` metadata and reject unresolved symbols.
8. Validate stage0 relocation metadata (`relocs`, including supported kind set from finobj reader) and reject unresolved relocation targets.
9. Materialize entry-object relocations into stage0 emitted code bytes using resolved provider symbol values (Linux supports `abs32`/`rel32`; Windows stage0 supports `abs32` only).
10. Reject non-entry relocation materialization, relocation offsets outside stage0 target code bounds, relocation offsets that are not supported stage0 patch sites for the selected target (Linux: 6, Windows: 1), and relocation kinds unsupported for the selected target.
11. Emit deterministic symbol-resolution witness hash for auditability.
12. Emit deterministic relocation-resolution witness hash for auditability (including relocation kind + resolved value in witness payload).
13. Expose deterministic structured linker diagnostics via `-AsRecord` (including object-set, symbol-resolution, relocation-resolution witness hashes, relocation applied count, and verification mode fields).
14. Emit final native image through direct emitter path with decoded entry exit code (`x86_64-linux-elf` or `x86_64-windows-pe`).
15. Expose `fin build/run --pipeline finobj` to route stage0 compilation through finobj+finld.
16. Optional structure verification after link; for relocation-patched outputs run verifier in patched-code mode (structure checks retained, strict immediate pattern check disabled), and report verification mode deterministically in diagnostics (`disabled|strict|structure_only_relocation_patched`).

This is a minimal multi-object checkpoint before full symbol-resolution and relocation support.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/integration/verify_finobj_link.ps1` validates multi-object finobj -> native link path for Linux ELF and Windows PE runtime behavior, including missing/duplicate entry-object rejection, duplicate path/identity rejection, unresolved symbol rejection, duplicate symbol provider rejection, relocation-bearing object checks (non-entry relocation rejection, entry relocation materialization, rel32 runtime behavior on Linux, symbol-value override behavior on Linux+Windows, relocation-bounds rejection, invalid-relocation-site rejection, unsupported-kind rejection for Windows rel32), verifier patched-code mode behavior for relocation-mutated outputs, order-independent output, stable linker diagnostics via `-AsRecord` (object-set, symbol-resolution, relocation-resolution witness hashes + verify mode fields), and PID-scoped age-gated temp workspace hygiene.
2. `tests/integration/verify_build_pipeline_finobj.ps1` validates Linux `fin build/run --pipeline finobj` and output parity with direct pipeline.
3. `tests/reproducibility/verify_stage0_reproducibility.ps1` validates deterministic multi-object linking for Linux/Windows, including stable output and stable `-AsRecord` diagnostics (witness hashes, applied relocation counts, and verify mode fields) under object input reordering for symbol + relocation metadata object sets.
4. `tests/run_stage0_suite.ps1` includes finld integration checks in `fin test`.

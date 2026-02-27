# FIP-0012: Windows PE Emitter

- id: FIP-0012
- address: fin://fip/FIP-0012
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0010"]
- target_release: M4
- discussion: TBD
- implementation:
  - compiler/finc/stage0/emit_pe_exit0.ps1
  - compiler/finc/stage0/build_stage0.ps1
  - cmd/fin/fin.ps1
  - tests/bootstrap/verify_pe_exit0.ps1
  - tests/integration/run_windows_pe.ps1
  - tests/integration/verify_windows_pe_exit.ps1
  - tests/integration/verify_build_target_windows.ps1
  - tests/run_stage0_suite.ps1
  - runtime/windows_x64/syscall-table.md
  - .github/workflows/ci.yml
- acceptance:
  - Compiler emits PE binaries that run on Windows without external runtime.

## Summary

Defines PE image emission for Windows x64 target.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 PE path:

1. Emits deterministic PE32+ image directly for x64 target.
2. Uses single `.text` section and minimal entry payload:
   - `mov eax, <u8>`
   - `ret`
3. Produces console subsystem executable with no import table.
4. Validates structure via deterministic header/section/payload checks.
5. Supports `fin build/run --target x86_64-windows-pe` in stage0 CLI.
6. Restricts Windows target to direct pipeline in stage0 (`--pipeline finobj` is rejected).

Runtime execution check:

1. On Windows hosts, runs emitted PE and validates process exit code.
2. On non-Windows hosts, runtime execution check is skipped while structure checks remain enforced.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/bootstrap/verify_pe_exit0.ps1` validates PE signature, headers, section metadata, and payload bytes.
2. `tests/integration/verify_windows_pe_exit.ps1` validates emit+verify flow and runtime exit on Windows.
3. `tests/integration/verify_build_target_windows.ps1` validates `fin build/run --target x86_64-windows-pe` and pipeline guard behavior.
4. `tests/run_stage0_suite.ps1` includes PE checks in `fin test`.
5. CI executes PE emit+verify structure checks on push/PR.

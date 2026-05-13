# FIP-0017: Lean Stdlib v0 (No-libc)

- id: FIP-0017
- address: fin://fip/FIP-0017
- status: Review
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0009", "FIP-0012"]
- target_release: M6
- discussion: TBD
- implementation:
  - docs/stdlib-v0.md
  - runtime/README.md
  - runtime/linux_x86_64/syscall-table.md
  - runtime/windows_x64/syscall-table.md
  - compiler/finc/stage0/emit_elf_exit0.ps1
  - compiler/finc/stage0/emit_elf_write_exit.ps1
  - compiler/finc/stage0/emit_pe_exit0.ps1
  - tests/bootstrap/verify_elf_exit0.ps1
  - tests/bootstrap/verify_elf_write_exit.ps1
  - tests/bootstrap/verify_pe_exit0.ps1
  - tests/integration/verify_linux_write_exit.ps1
  - tests/integration/verify_windows_pe_exit.ps1
  - tests/reproducibility/verify_stdlib_contract.ps1
  - tests/run_stage0_suite.ps1
- acceptance:
  - Stdlib API conformance and runtime ABI tests pass.

## Summary

Defines portable minimal standard library surface and constraints.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Review-stage no-libc contract is published in `docs/stdlib-v0.md`.

Current contract:

1. v0 stdlib must not depend on libc, CRT startup, shell commands, or external runtime libraries in normal build output.
2. `std.proc.exit(code: u8)` is the first process-control lane and maps to existing stage0 exit ABI evidence.
3. `std.io.write_stdout(bytes)` is the first output lane and maps to existing Linux `sys_write` evidence; Windows source-level stdout remains future work because current PE output has no import table and no external runtime dependency.
4. Current stage0 direct emitters are ABI witnesses until importable stdlib module names are available in the language.
5. Source-level stdlib module parsing/resolution and conformance fixtures are required before Implemented status.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/reproducibility/verify_stdlib_contract.ps1` validates the Review-stage no-libc stdlib contract references the required API lanes, ABI witnesses, runtime tables, and completion requirements.
2. `tests/bootstrap/verify_elf_exit0.ps1`, `tests/bootstrap/verify_elf_write_exit.ps1`, and `tests/bootstrap/verify_pe_exit0.ps1` validate the current direct runtime ABI witnesses.
3. `tests/integration/verify_linux_write_exit.ps1` validates Linux `sys_write + sys_exit` behavior without libc.
4. `tests/integration/verify_windows_pe_exit.ps1` validates PE structure and runtime exit on Windows hosts.
5. `tests/run_stage0_suite.ps1` includes the stdlib contract verifier.

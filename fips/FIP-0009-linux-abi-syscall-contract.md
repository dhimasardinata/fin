# FIP-0009: Linux ABI and Syscall Contract

- id: FIP-0009
- address: fin://fip/FIP-0009
- status: Implemented
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0010"]
- target_release: M1
- discussion: TBD
- implementation:
  - compiler/finc/stage0/emit_elf_exit0.ps1
  - compiler/finc/stage0/emit_elf_write_exit.ps1
  - tests/bootstrap/verify_elf_exit0.ps1
  - tests/bootstrap/verify_elf_write_exit.ps1
  - tests/integration/run_linux_elf.ps1
  - tests/integration/verify_linux_write_exit.ps1
  - tests/run_stage0_suite.ps1
  - runtime/linux_x86_64/syscall-table.md
- acceptance:
  - Hello-world and syscall smoke tests run on Linux without libc.

## Summary

Defines Linux x86_64 calling convention and syscall interface.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 ABI contract implemented:

1. Linux x86_64 syscall convention.
2. `sys_exit` syscall number `60` in `rax`.
3. `sys_write` syscall number `1` in `rax`.
4. `sys_exit` status in `rdi` (lower 8 bits relevant to process status).
5. `sys_write` arguments:
   - `rdi`: file descriptor
   - `rsi`: buffer pointer
   - `rdx`: byte length
6. Instruction sequences:
   - exit-only path:
     - `mov eax, 60`
     - `mov edi, <u8>`
     - `syscall`
   - write+exit path:
     - `mov eax, 1`
     - `mov edi, 1`
     - `mov rsi, <buf>`
     - `mov edx, <len>`
     - `syscall`
   - `mov eax, 60`
   - `mov edi, <u8>`
   - `syscall`

The generated ELF entrypoints execute these syscall sequences directly.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. ELF verifier asserts expected syscall payload bytes.
2. CLI build pipeline verifies emitted binary and expected encoded exit code.
3. Runtime integration executes emitted ELF and validates process exit code.
4. Runtime integration executes emitted write+exit ELF and validates stdout bytes plus exit code.

# FIP-0009: Linux ABI and Syscall Contract

- id: FIP-0009
- address: fin://fip/FIP-0009
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0010"]
- target_release: M1
- discussion: TBD
- implementation:
  - compiler/finc/stage0/emit_elf_exit0.ps1
  - tests/bootstrap/verify_elf_exit0.ps1
  - tests/integration/run_linux_elf.ps1
  - tests/run_stage0_suite.ps1
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
3. Exit status in `rdi` (lower 8 bits relevant to process status).
4. Instruction sequence:
   - `mov eax, 60`
   - `mov edi, <u8>`
   - `syscall`

The generated ELF entrypoint executes this sequence directly.

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

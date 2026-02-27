# FIP-0010: Direct ELF Emitter

- id: FIP-0010
- address: fin://fip/FIP-0010
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0005"]
- target_release: M1
- discussion: TBD
- implementation:
  - compiler/finc/stage0/emit_elf_exit0.ps1
  - compiler/finc/stage0/build_stage0.ps1
  - tests/bootstrap/verify_elf_exit0.ps1
  - .github/workflows/ci.yml
- acceptance:
  - Compiler emits runnable ELF binaries with valid headers/segments.

## Summary

Defines final ELF image emission without external linker.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current implementation provides a deterministic direct-ELF writer for Linux x86_64:

1. Emit a full ELF64 image directly into a byte buffer.
2. Include one PT_LOAD program header with RX permissions.
3. Embed a minimal syscall payload (`exit(<u8>)`).
4. Write final binary as a runnable artifact (`artifacts/fin-elf-exit0` by default).

The verifier asserts:

1. ELF ident and machine fields.
2. Program header layout and segment metadata.
3. Entry point and payload bytes.
4. Deterministic file hash reporting.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

CI now runs:

1. `compiler/finc/stage0/emit_elf_exit0.ps1`
2. `tests/bootstrap/verify_elf_exit0.ps1`
3. `cmd/fin/fin.ps1 build --src tests/conformance/fixtures/main_exit7.fn --out artifacts/fin-build-exit7`
4. `cmd/fin/fin.ps1 run --no-build --out artifacts/fin-build-exit7 --expect-exit 7`

These tests validate direct-image emission without assembler/linker usage.

# finc

`finc` is the Fin compiler track.

## Planned Pipeline

1. Lexer and parser.
2. Type inference and checking.
3. Ownership/borrow analysis.
4. Lowered IR.
5. Direct machine-code encoding.
6. Final executable image writer (ELF first, PE second).

## Current State

Implemented starter:

- `stage0/emit_elf_exit0.ps1` writes a deterministic Linux x86_64 ELF executable directly.
- `tests/bootstrap/verify_elf_exit0.ps1` validates ELF header, program header, entry point, and payload bytes.

Design and contracts continue to evolve under proposal control.

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

- `stage0/parse_main_exit.ps1` parses stage0 `.fn` subset with `let`/`var`/assignment and `exit`.
- `stage0/build_stage0.ps1` compiles source subset into an ELF executable.
- `stage0/emit_elf_exit0.ps1` writes a deterministic Linux x86_64 ELF executable directly.
- `stage0/emit_elf_write_exit.ps1` writes a deterministic Linux x86_64 ELF with `sys_write + sys_exit`.
- `stage0/emit_pe_exit0.ps1` writes a deterministic Windows x64 PE executable directly.
- `tests/bootstrap/verify_elf_exit0.ps1` validates ELF header, program header, entry point, and payload bytes.
- `tests/bootstrap/verify_elf_write_exit.ps1` validates ELF header, payload encoding, and embedded message data.
- `tests/bootstrap/verify_pe_exit0.ps1` validates PE header, section layout, entry point, and payload bytes.

Design and contracts continue to evolve under proposal control.

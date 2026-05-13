# finc

`finc` is the Fin compiler track.

## Compiler Pipeline Direction

1. Lexer and parser.
2. Type inference and checking.
3. Ownership/borrow analysis.
4. Lowered IR.
5. Direct machine-code encoding.
6. Final executable image writer (ELF first, PE second).

## Current State

Implemented stage0 path:

- `stage0/parse_main_exit.ps1` parses the current `.fn` bootstrap subset: typed helper functions, bindings, mutation, blocks, statement/expression `if`, `u8` operators, `Result<u8,u8>` bootstrap forms, ownership/borrow forms, and terminal `exit`/`return`.
- `stage0/build_stage0.ps1` compiles source subset into Linux ELF or Windows PE output through the direct pipeline or the `finobj` pipeline.
- `stage0/emit_elf_exit0.ps1` writes a deterministic Linux x86_64 ELF executable directly.
- `stage0/emit_elf_write_exit.ps1` writes a deterministic Linux x86_64 ELF with `sys_write + sys_exit`.
- `stage0/emit_pe_exit0.ps1` writes a deterministic Windows x64 PE executable directly.
- `stage0/format_main_exit.ps1` formats the stage0 `.fn` subset.
- `stage0/doc_main_exit.ps1` generates simple stage0 source documentation.
- `stage0/pkg_add.ps1` and `stage0/pkg_publish.ps1` implement deterministic manifest/lockfile and package artifact flows.
- `tests/bootstrap/verify_elf_exit0.ps1` validates ELF header, program header, entry point, and payload bytes.
- `tests/bootstrap/verify_elf_write_exit.ps1` validates ELF header, payload encoding, and embedded message data.
- `tests/bootstrap/verify_pe_exit0.ps1` validates PE header, section layout, entry point, and payload bytes.

Design and contracts continue to evolve under proposal control.

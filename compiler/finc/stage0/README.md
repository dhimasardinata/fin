# Stage0 Direct ELF Emitter

This directory contains the first executable implementation step for FIP-0010.

- `emit_elf_exit0.ps1`: emits a minimal Linux x86_64 ELF executable that exits with a requested code.
- `emit_elf_write_exit.ps1`: emits Linux x86_64 ELF that performs `sys_write` and then exits.
- `parse_main_exit.ps1`: parses stage0 `.fn` subset (`let`/`var`/assign/`exit`) and resolves final exit code.
- `build_stage0.ps1`: compiles `src/main.fn`-style input into a direct ELF output.
- `format_main_exit.ps1`: canonical formatter for the stage0 `.fn` subset.
- `doc_main_exit.ps1`: stage0 doc generator for the `.fn` subset.
- `pkg_add.ps1`: deterministic dependency section updates for `fin.toml`.
- `pkg_publish.ps1`: deterministic stage0 package artifact generator (`.fnpkg`).

The emitter writes a final ELF image directly (no assembler/linker).
It is intentionally tiny and deterministic to validate the direct-image pipeline.

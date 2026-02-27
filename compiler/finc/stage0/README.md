# Stage0 Direct ELF Emitter

This directory contains the first executable implementation step for FIP-0010.

- `emit_elf_exit0.ps1`: emits a minimal Linux x86_64 ELF executable that exits with a requested code.
- `parse_main_exit.ps1`: parses a minimal `.fn` subset and extracts `exit(<u8>)`.
- `build_stage0.ps1`: compiles `src/main.fn`-style input into a direct ELF output.

The emitter writes a final ELF image directly (no assembler/linker).
It is intentionally tiny and deterministic to validate the direct-image pipeline.

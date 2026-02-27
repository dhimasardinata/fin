# Stage0 Direct ELF Emitter

This directory contains the first executable implementation step for FIP-0010.

- `emit_elf_exit0.ps1`: emits a minimal Linux x86_64 ELF executable that exits with code 0.

The emitter writes a final ELF image directly (no assembler/linker).
It is intentionally tiny and deterministic to validate the direct-image pipeline.

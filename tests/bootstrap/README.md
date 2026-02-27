Bootstrap checks:

- `verify_elf_exit0.ps1`: validates ELF64 structure and `sys_exit` payload bytes.
- `verify_elf_write_exit.ps1`: validates ELF64 structure and `sys_write + sys_exit` payload bytes.
- `verify_pe_exit0.ps1`: validates PE32+ structure and exit payload bytes.
- `verify_stage0_closure.ps1`: validates stage0 bootstrap closure proxy hash (`gen1 == gen2`), writes witness metadata, and can verify against committed baseline.

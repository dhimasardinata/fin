Bootstrap checks:

- `verify_elf_exit0.ps1`: validates ELF64 structure and `sys_exit` payload bytes.
- `verify_elf_write_exit.ps1`: validates ELF64 structure and `sys_write + sys_exit` payload bytes.
- `verify_pe_exit0.ps1`: validates PE32+ structure and exit payload bytes.
- `verify_stage0_closure.ps1`: validates stage0 bootstrap closure proxy across Linux/Windows and direct/finobj matrix (`gen1 == gen2` + per-target pipeline parity), writes run-scoped witness metadata with atomic latest-witness mirror, self-validates witness contract, and prunes stale run workspaces with owner-metadata active-dir protection before baseline verification.

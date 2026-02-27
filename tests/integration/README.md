Integration checks:

- `run_linux_elf.ps1`: runs emitted Linux ELF binary and validates process exit code.
- `verify_init.ps1`: validates `fin init` scaffolding, overwrite protection, and force mode.

On Windows hosts this script uses WSL to execute Linux artifacts.
It is used by `./fin.ps1 run` and `./fin.ps1 test`.

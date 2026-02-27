Integration checks:

- `run_linux_elf.ps1`: runs emitted Linux ELF binary and validates process exit code.

On Windows hosts this script uses WSL to execute Linux artifacts.
It is used by `./fin.ps1 run` and `./fin.ps1 test`.

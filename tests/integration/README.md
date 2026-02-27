Integration checks:

- `run_linux_elf.ps1`: runs emitted Linux ELF binary and validates process exit code.
- `verify_init.ps1`: validates `fin init` scaffolding, overwrite protection, and force mode.
- `verify_fmt.ps1`: validates `fin fmt` canonical output and check mode behavior.
- `verify_doc.ps1`: validates `fin doc` file output and stdout behavior.
- `verify_pkg.ps1`: validates `fin pkg add` manifest + lockfile updates and validation errors.
- `verify_pkg_publish.ps1`: validates `fin pkg publish` artifact generation, determinism, and dry-run behavior.

On Windows hosts this script uses WSL to execute Linux artifacts.
It is used by `./fin.ps1 run` and `./fin.ps1 test`.

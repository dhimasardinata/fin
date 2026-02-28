Integration checks:

- `run_linux_elf.ps1`: runs emitted Linux ELF binary and validates process exit code.
- `verify_init.ps1`: validates `fin init` scaffolding, overwrite protection, and force mode.
- `verify_fmt.ps1`: validates `fin fmt` canonical output and check mode behavior.
- `verify_doc.ps1`: validates `fin doc` file output and stdout behavior.
- `verify_pkg.ps1`: validates `fin pkg add` manifest + lockfile updates and validation errors.
- `verify_pkg_publish.ps1`: validates `fin pkg publish` artifact generation, determinism, and dry-run behavior.
- `verify_linux_write_exit.ps1`: validates Linux `sys_write + sys_exit` emitted ELF behavior and stdout.
- `verify_windows_pe_exit.ps1`: validates Windows PE emit/verify flow and runtime exit code on Windows hosts.
- `verify_build_target_windows.ps1`: validates `fin build/run --target x86_64-windows-pe` flow for both `direct` and `finobj` pipelines.
- `verify_manifest_target_resolution.ps1`: validates `fin build/run` target selection from `fin.toml` (`[targets].primary`) and explicit target override.
- `verify_finobj_link.ps1`: validates stage0 finobj multi-object link path for Linux ELF and Windows PE runtime behavior, including missing/duplicate entry-object rejection, duplicate path/identity rejection, unresolved/duplicate symbol rejection, relocation-bearing object checks, entry relocation materialization semantics (Linux `abs32`/`rel32`, Windows `abs32`), symbol-value override behavior, relocation-bounds/invalid-site rejection, Windows unsupported-kind rejection (`rel32`), order-independent output, and stable linker witness hashes via `-AsRecord` (object-set, symbol-resolution, relocation-resolution).
- `verify_build_pipeline_finobj.ps1`: validates `fin build/run --pipeline finobj` path and parity with direct pipeline output.

On Windows hosts this script uses WSL to execute Linux artifacts.
It is used by `./fin.ps1 run` and `./fin.ps1 test`.

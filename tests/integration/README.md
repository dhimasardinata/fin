Integration checks:

- `run_linux_elf.ps1`: runs emitted Linux ELF binary and validates process exit code.
- `verify_init.ps1`: validates `fin init` scaffolding, overwrite protection, and force mode, with PID-scoped temp workspace hygiene.
- `verify_fmt.ps1`: validates `fin fmt` canonical output and check mode behavior, with PID-scoped temp workspace hygiene.
- `verify_doc.ps1`: validates `fin doc` file output and stdout behavior, with PID-scoped temp workspace hygiene.
- `verify_pkg.ps1`: validates `fin pkg add` manifest + lockfile updates and validation errors, with PID-scoped temp workspace hygiene.
- `verify_pkg_publish.ps1`: validates `fin pkg publish` artifact generation, determinism, and dry-run behavior, with PID-scoped temp workspace hygiene.
- `verify_linux_write_exit.ps1`: validates Linux `sys_write + sys_exit` emitted ELF behavior and stdout.
- `verify_windows_pe_exit.ps1`: validates Windows PE emit/verify flow and runtime exit code on Windows hosts.
- `verify_build_target_windows.ps1`: validates `fin build/run --target x86_64-windows-pe` flow for both `direct` and `finobj` pipelines, with PID-scoped temp workspace hygiene and stage0 finobj temp artifact cleanup checks.
- `verify_manifest_target_resolution.ps1`: validates `fin build/run` target selection from `fin.toml` (`[targets].primary`) and explicit target override, with PID-scoped temp workspace hygiene, direct/finobj parity checks, and stage0 finobj temp artifact cleanup checks.
- `verify_finobj_link.ps1`: validates stage0 finobj multi-object link path for Linux ELF and Windows PE runtime behavior, including missing/duplicate entry-object rejection, duplicate path/identity rejection, unresolved/duplicate symbol rejection, relocation-bearing object checks, non-entry relocation rejection, entry relocation materialization semantics (Linux `abs32`/`rel32`, Windows `abs32`), symbol-value override behavior, relocation-bounds/invalid-site rejection, Windows unsupported-kind rejection (`rel32`), verifier patched-code mode checks (`-AllowPatchedCode`), order-independent output, and stable linker diagnostics via `-AsRecord` (object-set/symbol-resolution/relocation-resolution witness hashes + verify mode fields).
- `verify_build_pipeline_finobj.ps1`: validates `fin build/run --pipeline finobj` path and parity with direct pipeline output, with PID-scoped temp workspace hygiene and stage0 finobj temp artifact cleanup checks.

Shared helper: `tests/common/finobj_output_helpers.ps1` for parsing `finobj_written=...` output in finobj pipeline integration checks.

On Windows hosts this script uses WSL to execute Linux artifacts.
It is used by `./fin.ps1 run` and `./fin.ps1 test`.

`verify_finobj_link.ps1`, `verify_build_pipeline_finobj.ps1`, `verify_build_target_windows.ps1`, `verify_manifest_target_resolution.ps1`, `verify_init.ps1`, `verify_fmt.ps1`, `verify_doc.ps1`, `verify_pkg.ps1`, and `verify_pkg_publish.ps1` use PID-scoped temp directories under `artifacts/tmp` and prune stale `finobj-link-*` / `build-pipeline-smoke-*` / `build-target-windows-smoke-*` / `manifest-target-smoke-*` / `init-smoke-*` / `fmt-smoke-*` / `doc-smoke-*` / `pkg-smoke-*` / `pkg-publish-smoke-*` temp dirs by default.
Set `FIN_KEEP_TEST_TMP=1` to retain those temp artifacts for local debugging.
The default stale-prune window is 6 hours and is configurable with `FIN_TEST_TMP_STALE_HOURS`.
Stale prune skips PID-owned temp dirs when the owning process is still active.
PID ownership checks also validate owner metadata (`pid` + process start time) when present.
Malformed owner metadata falls back to PID-active checks and active directories are backfilled with repaired metadata.
Legacy PID-only dirs without metadata remain compatible: active PID dirs are preserved and backfilled with metadata, inactive PID dirs are pruned.

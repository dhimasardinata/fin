# Tests

Test families:

- `bootstrap/`: closure and seed verification.
- `conformance/`: parser, types, ownership, and semantics.
- `reproducibility/`: deterministic build checks.
- `integration/`: runtime and ABI tests.

Entry points:

- `tests/run_stage0_suite.ps1`: aggregated stage0 `fin test` suite.
- `tests/reproducibility/verify_stage0_reproducibility.ps1`: stage0 reproducibility hash gate (emit/build/publish/finobj/finld), including `finld` object-set, symbol-resolution, relocation-resolution witness-hash determinism, applied-relocation count stability checks, and verify-diagnostics mode checks (`LinkedVerifyEnabled`/`LinkedVerifyMode`).
- `tests/reproducibility/verify_test_tmp_workspace_policy.ps1`: shared test temp-workspace policy gate (PID-scoped init/finalize, keep-mode retention, age-gated stale pruning with active-PID and owner-metadata validation, invalid-metadata PID fallback, legacy PID-only compatibility, env validation, static guard against hardcoded `artifacts/tmp/<prefix>` roots in test scripts, and centralized finobj output helper enforcement including capture/parsing and SHA256 parity assertions).
- `tests/bootstrap/verify_stage0_closure.ps1`: stage0 bootstrap closure witness gate.
- `tests/bootstrap/verify_pe_exit0.ps1`: stage0 Windows PE image structure gate.
- `tests/conformance/verify_finobj_roundtrip.ps1`: stage0 finobj reader/writer and malformed-object validation gate, including canonical symbol-order validation, symbol-value metadata validation (`symbol_values`), and relocation metadata validation (kind defaults + supported-kind checks), with PID-scoped temp workspace hygiene.
- `tests/integration/verify_finobj_link.ps1`: stage0 finld minimal multi-object link gate for Linux ELF and Windows PE, including deterministic order-independence, duplicate rejection, symbol/relocation validation checks, non-entry relocation rejection, entry relocation materialization checks (Linux `abs32`/`rel32`, Windows `abs32`), symbol-value override behavior, relocation-bounds/invalid-site rejection, Windows unsupported-kind rejection (`rel32`), relocation-patched verifier mode checks (`-AllowPatchedCode`), and `-AsRecord` diagnostics checks (object-set/symbol-resolution/relocation-resolution witness hashes + verify mode fields).
- `tests/integration/verify_build_target_windows.ps1`: stage0 `fin build/run --target x86_64-windows-pe` integration gate for both pipelines, with PID-scoped temp workspace hygiene and stage0 finobj temp artifact cleanup checks.
- `tests/integration/verify_manifest_target_resolution.ps1`: stage0 target resolution from manifest primary gate with PID-scoped temp workspace hygiene, direct/finobj parity checks, and stage0 finobj temp artifact cleanup checks.
- `tests/integration/verify_build_pipeline_finobj.ps1`: stage0 `fin build/run --pipeline finobj` integration gate with PID-scoped temp workspace hygiene and stage0 finobj temp artifact cleanup checks.
- `tests/integration/verify_init.ps1`: `fin init` scaffolding integration gate with PID-scoped temp workspace hygiene.
- `tests/integration/verify_fmt.ps1`: `fin fmt` integration gate with PID-scoped temp workspace hygiene.
- `tests/integration/verify_doc.ps1`: `fin doc` integration gate with PID-scoped temp workspace hygiene.
- `tests/integration/verify_pkg.ps1`: `fin pkg add` integration gate with PID-scoped temp workspace hygiene.
- `tests/integration/verify_pkg_publish.ps1`: `fin pkg publish` integration gate with PID-scoped temp workspace hygiene.
- `tests/reproducibility/verify_manifest_policy_gate.ps1`: manifest policy gate self-check coverage with PID-scoped temp workspace hygiene.
- `tests/reproducibility/verify_toolchain_policy_gate.ps1`: toolchain policy gate self-check coverage with PID-scoped temp workspace hygiene.

Temporary workspace policy:

- `verify_finobj_roundtrip.ps1`, `verify_finobj_link.ps1`, `verify_build_pipeline_finobj.ps1`, `verify_build_target_windows.ps1`, `verify_manifest_target_resolution.ps1`, `verify_init.ps1`, `verify_fmt.ps1`, `verify_doc.ps1`, `verify_pkg.ps1`, `verify_pkg_publish.ps1`, `verify_manifest_policy_gate.ps1`, `verify_toolchain_policy_gate.ps1`, and `verify_stage0_reproducibility.ps1` use PID-scoped temp roots under `artifacts/tmp` and prune stale temp dirs from prior runs.
- Set `FIN_KEEP_TEST_TMP=1` to retain per-run temp artifacts for local debugging.
- Stale pruning keeps recent temp dirs and skips stale dirs whose PID owner is still active with matching owner metadata (`pid` + process start time); malformed metadata falls back to PID-active checks and active dirs are backfilled with repaired metadata.
- Legacy PID-only dirs without owner metadata are still supported: active PID dirs are preserved and backfilled with owner metadata; inactive PID dirs are pruned.
- Default staleness window is 6 hours and can be tuned via `FIN_TEST_TMP_STALE_HOURS`.
- Shared helper implementations: `tests/common/test_tmp_workspace.ps1` (PID-scoped temp-workspace lifecycle + bounded cleanup retries) and `tests/common/finobj_output_helpers.ps1` (`finobj_written` output capture/parsing + finobj temp-artifact cleanup + SHA256 parity assertion helpers).

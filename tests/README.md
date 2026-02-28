# Tests

Test families:

- `bootstrap/`: closure and seed verification.
- `conformance/`: parser, types, ownership, and semantics.
- `reproducibility/`: deterministic build checks.
- `integration/`: runtime and ABI tests.

Entry points:

- `tests/run_stage0_suite.ps1`: aggregated stage0 `fin test` suite.
- `tests/reproducibility/verify_stage0_reproducibility.ps1`: stage0 reproducibility hash gate (emit/build/publish/finobj/finld), including `finld` object-set, symbol-resolution, relocation-resolution witness-hash determinism, applied-relocation count stability checks, and verify-diagnostics mode checks (`LinkedVerifyEnabled`/`LinkedVerifyMode`).
- `tests/bootstrap/verify_stage0_closure.ps1`: stage0 bootstrap closure witness gate.
- `tests/bootstrap/verify_pe_exit0.ps1`: stage0 Windows PE image structure gate.
- `tests/conformance/verify_finobj_roundtrip.ps1`: stage0 finobj reader/writer and malformed-object validation gate, including canonical symbol-order validation, symbol-value metadata validation (`symbol_values`), and relocation metadata validation (kind defaults + supported-kind checks).
- `tests/integration/verify_finobj_link.ps1`: stage0 finld minimal multi-object link gate for Linux ELF and Windows PE, including deterministic order-independence, duplicate rejection, symbol/relocation validation checks, non-entry relocation rejection, entry relocation materialization checks (Linux `abs32`/`rel32`, Windows `abs32`), symbol-value override behavior, relocation-bounds/invalid-site rejection, Windows unsupported-kind rejection (`rel32`), relocation-patched verifier mode checks (`-AllowPatchedCode`), and `-AsRecord` diagnostics checks (object-set/symbol-resolution/relocation-resolution witness hashes + verify mode fields).
- `tests/integration/verify_build_target_windows.ps1`: stage0 `fin build/run --target x86_64-windows-pe` integration gate for both pipelines.
- `tests/integration/verify_manifest_target_resolution.ps1`: stage0 target resolution from manifest primary gate.
- `tests/integration/verify_build_pipeline_finobj.ps1`: stage0 `fin build/run --pipeline finobj` integration gate.
- `tests/reproducibility/verify_manifest_policy_gate.ps1`: manifest policy gate self-check coverage.

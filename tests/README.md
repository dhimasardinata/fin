# Tests

Test families:

- `bootstrap/`: closure and seed verification.
- `conformance/`: parser, types, ownership, and semantics.
- `reproducibility/`: deterministic build checks.
- `integration/`: runtime and ABI tests.

Entry points:

- `tests/run_stage0_suite.ps1`: aggregated stage0 `fin test` suite.
- `tests/reproducibility/verify_stage0_reproducibility.ps1`: stage0 reproducibility hash gate (emit/build/publish/finobj/finld), including `finld` object-set, symbol-resolution, relocation-resolution witness-hash determinism, and applied-relocation count stability checks.
- `tests/bootstrap/verify_stage0_closure.ps1`: stage0 bootstrap closure witness gate.
- `tests/bootstrap/verify_pe_exit0.ps1`: stage0 Windows PE image structure gate.
- `tests/conformance/verify_finobj_roundtrip.ps1`: stage0 finobj reader/writer and malformed-object validation gate, including canonical symbol-order validation, symbol-value metadata validation (`symbol_values`), and relocation metadata validation (kind defaults + supported-kind checks).
- `tests/integration/verify_finobj_link.ps1`: stage0 finld minimal multi-object link gate for Linux ELF and Windows PE, including deterministic order-independence, duplicate rejection, symbol/relocation validation checks, entry relocation materialization checks (`abs32`/`rel32`), symbol-value override behavior, relocation-bounds rejection, and `-AsRecord` witness-hash stability (object-set, symbol-resolution, relocation-resolution).
- `tests/integration/verify_build_target_windows.ps1`: stage0 `fin build/run --target x86_64-windows-pe` integration gate for both pipelines.
- `tests/integration/verify_manifest_target_resolution.ps1`: stage0 target resolution from manifest primary gate.
- `tests/integration/verify_build_pipeline_finobj.ps1`: stage0 `fin build/run --pipeline finobj` integration gate.
- `tests/reproducibility/verify_manifest_policy_gate.ps1`: manifest policy gate self-check coverage.

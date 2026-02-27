# Tests

Test families:

- `bootstrap/`: closure and seed verification.
- `conformance/`: parser, types, ownership, and semantics.
- `reproducibility/`: deterministic build checks.
- `integration/`: runtime and ABI tests.

Entry points:

- `tests/run_stage0_suite.ps1`: aggregated stage0 `fin test` suite.
- `tests/reproducibility/verify_stage0_reproducibility.ps1`: stage0 reproducibility hash gate.
- `tests/bootstrap/verify_stage0_closure.ps1`: stage0 bootstrap closure witness gate.

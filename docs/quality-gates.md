# Quality Gates

## Mandatory Checks

1. FIP link check for non-trivial feature changes.
2. External toolchain prohibition gate.
3. Reproducibility evidence gate.
4. Seed hash verification gate.

Current script gates:

- `ci/forbid_external_toolchain.ps1`
- `tests/reproducibility/verify_toolchain_policy_gate.ps1`
- `tests/reproducibility/verify_stage0_reproducibility.ps1`

## Test Families

- Conformance tests.
- Bootstrap closure tests.
- Runtime ABI behavior tests.
- Determinism and reproducibility tests.

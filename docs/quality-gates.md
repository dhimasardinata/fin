# Quality Gates

## Mandatory Checks

1. FIP link check for non-trivial feature changes.
2. External toolchain prohibition gate.
3. Reproducibility evidence gate.
4. Seed hash verification gate.

Current script gates:

- `ci/verify_fip_metadata.ps1`
- `ci/check_fip_link.ps1`
- `ci/verify_manifest.ps1`
- `ci/verify_seed_hash.ps1`
- `ci/forbid_external_toolchain.ps1`
- `tests/reproducibility/verify_manifest_policy_gate.ps1`
- `tests/reproducibility/verify_fip_metadata_policy_gate.ps1`
- `tests/reproducibility/verify_fip_policy_gate.ps1`
- `tests/reproducibility/verify_stage0_reproducibility.ps1`
- `tests/reproducibility/verify_toolchain_policy_gate.ps1`
- `tests/reproducibility/verify_closure_baseline_contract.ps1`
- `tests/bootstrap/verify_stage0_closure.ps1`
- `seed/stage0-closure-baseline.txt` (closure witness baseline input)

## Test Families

- Conformance tests.
- Integration tests.
- Bootstrap closure tests.
- Runtime ABI behavior tests.
- Determinism and reproducibility tests.
- Governance and policy self-checks.

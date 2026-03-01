Reproducibility checks:

- `verify_stage0_reproducibility.ps1`: validates deterministic hashes across repeated stage0 emit/build/publish operations.
- `verify_closure_workspace_policy.ps1`: validates stage0 closure run-workspace stale-pruning policy with owner-metadata safety (`pid` + `start_utc`), including mismatched-metadata pruning, invalid-metadata fallback+repair, legacy PID-only backfill, and stale-hours env validation.
- `verify_manifest_policy_gate.ps1`: validates manifest policy gate behavior for valid and invalid target/policy combinations, with PID-scoped temp workspace hygiene.
- `verify_toolchain_policy_gate.ps1`: validates external-toolchain CI gate behavior against disallowed workflow content, with PID-scoped temp workspace hygiene.

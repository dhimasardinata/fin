Reproducibility checks:

- `verify_stage0_reproducibility.ps1`: validates deterministic hashes across repeated stage0 emit/build/publish operations.
- `verify_ownership_borrow_contract.ps1`: validates the checked FIP-0007 stage0 ownership/borrow contract across FIP status, parser lifecycle hooks, conformance diagnostics, runtime fixture coverage, and aggregated suite wiring.
- `verify_closure_workspace_policy.ps1`: validates stage0 closure run-workspace stale-pruning policy with owner-metadata safety (`pid` + `start_utc`), including invalid keep/stale env fail-fast checks (stale-hours validation also enforced on keep-mode path), `FIN_KEEP_CLOSURE_RUNS=1` keep-mode bypass across consecutive runs, malformed run-name pruning, non-positive/overflow/non-parseable PID run-name pruning, non-run stale-dir retention, mismatched-metadata pruning, invalid-metadata fallback+repair, and legacy PID-only backfill.
- `verify_manifest_policy_gate.ps1`: validates manifest policy gate behavior for valid and invalid target/policy combinations, with PID-scoped temp workspace hygiene.
- `verify_toolchain_policy_gate.ps1`: validates external-toolchain CI gate behavior against disallowed workflow content, with PID-scoped temp workspace hygiene.

# FIP-0011: Self-Hosting Closure Criteria

- id: FIP-0011
- address: fin://fip/FIP-0011
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0003", "FIP-0010"]
- target_release: M3
- discussion: TBD
- implementation:
  - tests/bootstrap/verify_stage0_closure.ps1
  - tests/reproducibility/verify_closure_baseline_contract.ps1
  - tests/reproducibility/verify_closure_baseline_contract_policy_gate.ps1
  - tests/reproducibility/verify_closure_workspace_policy.ps1
  - seed/stage0-closure-baseline.txt
  - tests/run_stage0_suite.ps1
  - docs/bootstrap.md
- acceptance:
  - Stage0 proxy closure hash is stable in CI.
  - fin-seed -> finc -> finc closure hash is stable in CI before release status.

## Summary

Defines deterministic bootstrap closure checks and hash criteria.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 closure proxy:

1. Build a fixed representative source input twice for each stage0 matrix case:
   - `x86_64-linux-elf` + `direct`
   - `x86_64-linux-elf` + `finobj`
   - `x86_64-windows-pe` + `direct`
   - `x86_64-windows-pe` + `finobj`
2. Require per-case deterministic equality (`sha256(gen1) == sha256(gen2)`).
3. Require direct/finobj parity for each target (Linux and Windows).
4. Compute and record snapshot hashes for:
   - seed metadata files (`seed/manifest.toml`, `seed/SHA256SUMS`)
   - stage0 toolchain control scripts (`cmd/fin/fin.ps1`, stage0 build/parser/emit/finobj/finld scripts)
5. Write closure witness record to a run-scoped path (`artifacts/closure/run-*/stage0-closure-witness.txt`) and mirror latest successful witness atomically to `artifacts/closure/stage0-closure-witness.txt`.
6. Validate emitted witness contract in stage0 test suite with strict keyset checks (missing/mismatch/unexpected key rejection), duplicate-key rejection, and canonical key-order validation before baseline comparison.
7. Compare validated closure witness keys/values to committed baseline (`seed/stage0-closure-baseline.txt`) with strict keyset validation (missing/mismatch/unexpected key rejection), duplicate-key rejection, and canonical key-order validation.
8. Statically validate the committed baseline contract before the heavier closure run, including case-sensitive key order, duplicate/unexpected key rejection, hash formats, parity booleans, direct/finobj equality, source existence, and closure hash derivation from matrix hashes.
9. Materialize closure build outputs in a uniquely tokenized run-scoped workspace under `artifacts/closure` using run-tokenized output basenames to avoid cross-run collisions in both final outputs and stage0 intermediate finobj temp paths.
10. Prune stale run workspaces under `artifacts/closure` before each run with age-gated policy (default 24h; configurable via `FIN_CLOSURE_STALE_HOURS`; bypass only when `FIN_KEEP_CLOSURE_RUNS=1`; invalid keep values rejected; invalid stale-hours rejected even when keep mode is set), scoped to `run-*` directories only, using owner metadata (`pid` + `start_utc`) for active-owner protection with legacy PID fallback/backfill.
11. The committed baseline source is a representative stage0 fixture that exercises helper calls, typed parameters, statement-form `while`, mutation, and terminal `return` before entrypoint `exit`.

This proxy establishes deterministic closure evidence before native self-hosting exists.
Full `fin-seed -> finc -> finc` closure remains the completion requirement for Implemented status.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/bootstrap/verify_stage0_closure.ps1` validates deterministic `gen1 == gen2` for all stage0 target/pipeline matrix cases, target-level direct/finobj parity, run-scoped closure workspace isolation, witness contract self-validation (keys/order/values), and stale-run workspace pruning safety with owner-metadata active-dir protection.
2. `tests/reproducibility/verify_closure_baseline_contract.ps1` validates the committed closure baseline key contract and derived closure hash before the heavier closure run.
3. `tests/reproducibility/verify_closure_baseline_contract_policy_gate.ps1` covers negative contract cases for wrong-case keys/values, lowercase `UNSET`, uppercase hashes, and uppercase parity booleans.
4. `tests/run_stage0_suite.ps1` includes closure check in `fin test`.
5. Stage0 suite verifies validated closure witness against committed baseline with strict required-key equality, duplicate-key rejection, and canonical key-order validation.
6. `tests/reproducibility/verify_closure_workspace_policy.ps1` validates closure stale-pruning policy scenarios (invalid keep env rejection, invalid stale-hours env rejection including keep-mode path, `FIN_KEEP_CLOSURE_RUNS=1` keep-mode prune bypass across consecutive runs, distinct repeated run workspaces, active legacy PID-only backfill, invalid-metadata fallback+repair, malformed run-name pruning, non-positive/overflow/non-parseable PID run-name pruning, non-run stale-dir retention, mismatched metadata pruning, inactive-dir pruning).
7. CI executes `cmd/fin/fin.ps1 test --no-doctor` on push/PR.

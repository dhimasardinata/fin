# Bootstrap Model

Fin bootstrap uses an audited seed model.

## Trust Anchor

- A small seed artifact is versioned in `seed/`.
- The artifact hash is pinned in repository metadata.
- Release lines cannot silently rotate seed hash.

## Closure Requirement

`fin-seed -> finc -> finc` must converge to identical hashes for deterministic closure.

## Current Stage0 Proxy

Until native self-hosting is available, stage0 closure evidence is produced by:

- `tests/bootstrap/verify_stage0_closure.ps1`

Proxy rule:

1. Build the same source twice for each stage0 matrix case:
   - Linux ELF `direct`
   - Linux ELF `finobj`
   - Windows PE `direct`
   - Windows PE `finobj`
2. Require generation-1 and generation-2 output hashes to match per case.
3. Require direct/finobj pipeline parity per target.
4. Emit witness metadata in a run-scoped file (`artifacts/closure/run-*/stage0-closure-witness.txt`) and mirror the latest successful witness atomically to `artifacts/closure/stage0-closure-witness.txt`.
5. Self-validate emitted witness contract before baseline checks (strict keyset matching, duplicate-key rejection, canonical key-order validation, and deterministic value checks).
6. Verify witness keys/values against committed baseline `seed/stage0-closure-baseline.txt` with strict keyset matching, duplicate-key rejection, and canonical key-order validation.
7. Use a run-scoped closure workspace under `artifacts/closure` with run-tokenized output basenames so concurrent closure runs do not collide on output filenames or stage0 intermediate finobj temp names.
8. Prune stale `run-*` closure workspaces with age gating (default 24h; override via `FIN_CLOSURE_STALE_HOURS`; disable only via `FIN_KEEP_CLOSURE_RUNS=1`; invalid keep values fail fast) while protecting active-owner directories via owner metadata (`pid` + `start_utc`) and legacy PID fallback/backfill.

## Constraints

- Normal build path remains fully independent.
- Bootstrap exceptions must be explicit and ratified by proposal.

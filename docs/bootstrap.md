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

1. Build the same source twice using current stage0 toolchain path.
2. Require generation-1 and generation-2 output hashes to match.
3. Emit witness metadata at `artifacts/closure/stage0-closure-witness.txt`.
4. Verify witness keys against committed baseline `seed/stage0-closure-baseline.txt`.

## Constraints

- Normal build path remains fully independent.
- Bootstrap exceptions must be explicit and ratified by proposal.

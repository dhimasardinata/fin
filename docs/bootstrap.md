# Bootstrap Model

Fin bootstrap uses an audited seed model.

## Trust Anchor

- A small seed artifact is versioned in `seed/`.
- The artifact hash is pinned in repository metadata.
- Release lines cannot silently rotate seed hash.

## Closure Requirement

`fin-seed -> finc -> finc` must converge to identical hashes for deterministic closure.

## Constraints

- Normal build path remains fully independent.
- Bootstrap exceptions must be explicit and ratified by proposal.

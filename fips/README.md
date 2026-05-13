# Fin Improvement Proposals (FIPs)

## Naming

- ID format: `FIP-####`.
- URI format: `fin://fip/FIP-####`.
- File format: `FIP-####-<slug>.md`.

## Required Metadata

- `id`
- `status`
- `authors`
- `created`
- `requires`
- `target_release`
- `discussion`
- `implementation`
- `acceptance`

The title is not separate metadata. It is the canonical header:
`# FIP-####: <Title>`.

`created` uses the canonical `YYYY-MM-DD` date format, and `authors` must not
be empty.

`target_release` uses the canonical `M<number>` milestone format.

`requires` entries must be canonical FIP IDs, unique, and must not reference the
same FIP.

`discussion` must be `TBD`, a canonical `fin://fip/FIP-####` URI, or an
`http(s)` URL.

`acceptance` must contain at least one criteria item.

Implemented and released FIPs must replace placeholder discussion metadata.
Bootstrap records without an external thread use their canonical `fin://fip/...`
address instead of `TBD`.

## Status Lifecycle

`Draft -> Review -> Accepted -> Scheduled -> InProgress -> Implemented -> Released`

Side statuses: `Deferred`, `Rejected`.

## Merge Rule

Feature pull requests must link a FIP in status `Accepted`, `Scheduled`, `InProgress`, `Implemented`, or `Released`.

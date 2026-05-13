# Fin Improvement Proposals (FIPs)

## Naming

- ID format: `FIP-####`.
- URI format: `fin://fip/FIP-####`.
- File format: `FIP-####-<slug>.md`.

## Required Metadata

- `id`
- `title`
- `status`
- `authors`
- `created`
- `requires`
- `target_release`
- `discussion`
- `implementation`
- `acceptance`

Implemented and released FIPs must replace placeholder discussion metadata.
Bootstrap records without an external thread use their canonical `fin://fip/...`
address instead of `TBD`.

## Status Lifecycle

`Draft -> Review -> Accepted -> Scheduled -> InProgress -> Implemented -> Released`

Side statuses: `Deferred`, `Rejected`.

## Merge Rule

Feature pull requests must link a FIP in status `Accepted`, `Scheduled`, `InProgress`, `Implemented`, or `Released`.

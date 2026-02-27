# FIP-0016: Package Manifest and Lockfile

- id: FIP-0016
- address: fin://fip/FIP-0016
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0015"]
- target_release: M6
- discussion: TBD
- implementation:
  - compiler/finc/stage0/pkg_add.ps1
  - cmd/fin/fin.ps1
  - tests/integration/verify_pkg.ps1
  - tests/run_stage0_suite.ps1
- acceptance:
  - Deterministic resolution and lockfile update tests pass.

## Summary

Defines fin.toml and fin.lock schema and behavior.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 package behavior:

1. `fin pkg add <name[@version]>` mutates manifest dependencies.
2. `--version` overrides inline `@version`.
3. `--manifest` selects non-default manifest path.
4. `[dependencies]` section is created when missing.
5. Dependency entries are rewritten in sorted-key order for deterministic diffs.
6. Re-adding an existing package updates its version.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/integration/verify_pkg.ps1` validates create/add/update/failure paths.
2. `tests/run_stage0_suite.ps1` executes package checks as part of `fin test`.

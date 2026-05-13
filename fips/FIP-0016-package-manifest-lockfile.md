# FIP-0016: Package Manifest and Lockfile

- id: FIP-0016
- address: fin://fip/FIP-0016
- status: Implemented
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0015"]
- target_release: M6
- discussion: fin://fip/FIP-0016
- implementation:
  - compiler/finc/stage0/pkg_add.ps1
  - compiler/finc/stage0/pkg_publish.ps1
  - cmd/fin/fin.ps1
  - ci/verify_manifest.ps1
  - tests/integration/verify_pkg.ps1
  - tests/integration/verify_pkg_publish.ps1
  - tests/reproducibility/verify_manifest_policy_gate.ps1
  - tests/run_stage0_suite.ps1
- acceptance:
  - Deterministic manifest, lockfile, and package artifact tests pass.

## Summary

Defines fin.toml and fin.lock schema and behavior.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 package behavior:

1. `fin pkg add <name[@version]>` validates manifest policy before mutating dependencies.
2. `--version` overrides inline `@version`.
3. `--manifest` selects non-default manifest path.
4. `[dependencies]` section is created when missing.
5. Dependency entries are rewritten in sorted-key order for deterministic diffs.
6. Re-adding an existing package updates its version.
7. `fin pkg add` rewrites `fin.lock` as a machine-managed deterministic snapshot.
8. Lockfile entries are sorted by dependency name for stable diffs.
9. `fin pkg publish` validates manifest policy, then emits deterministic `.fnpkg` artifact from `fin.toml`, `fin.lock` (if present), and `src/**/*.fn`.
10. `fin pkg publish --dry-run` reports metadata/hash without writing artifact.
11. `verify_manifest` enforces workspace identity, version, seed-hash syntax, canonical boolean policy fields, target schema (`[targets].primary/secondary`), and dependency entry syntax.
12. `fin build`, `fin run`, `fin pkg add`, and `fin pkg publish` validate the selected manifest before using it.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

This locks the stage0 `fin.toml` and `fin.lock` fields used by package,
publish, and target-selection flows. Incompatible schema changes require an
explicit FIP/test update or a documented migration path.

## Test Plan

Current checks:

1. `tests/integration/verify_pkg.ps1` validates manifest + lockfile create/add/update/failure paths, including manifest-policy rejection before mutation.
2. `tests/integration/verify_pkg_publish.ps1` validates publish output, determinism, dry-run behavior, and manifest-policy rejection.
3. `tests/reproducibility/verify_manifest_policy_gate.ps1` validates manifest policy gate pass/fail behavior, including workspace identity, version, seed-hash syntax, target schema, dependency entry syntax, canonical booleans, and policy switches.
4. `tests/integration/verify_manifest_target_resolution.ps1` validates command-path manifest policy enforcement before build/run target resolution.
5. `tests/run_stage0_suite.ps1` executes package and manifest-policy checks as part of `fin test`.

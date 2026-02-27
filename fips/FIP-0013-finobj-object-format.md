# FIP-0013: Fin Object Format (finobj)

- id: FIP-0013
- address: fin://fip/FIP-0013
- status: Implemented
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0010"]
- target_release: M5
- discussion: TBD
- implementation:
  - compiler/finobj/stage0/write_finobj_exit.ps1
  - compiler/finobj/stage0/read_finobj_exit.ps1
  - tests/conformance/verify_finobj_roundtrip.ps1
  - tests/run_stage0_suite.ps1
- acceptance:
  - Object reader/writer round-trip tests pass.

## Summary

Defines relocatable object format for multi-unit builds.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 finobj format is deterministic key-value text with required fields:

1. `finobj_format=finobj-stage0`
2. `finobj_version=1`
3. `target=<x86_64-linux-elf|x86_64-windows-pe>`
4. `entry_symbol=<main|unit>`
5. `exit_code=<0..255>`
6. `source_path=<repo-relative path>`
7. `source_sha256=<normalized source hash>`

Stage0 scope is still minimal; `entry_symbol=unit` enables linker multi-object checkpoint while full relocations/symbol tables remain deferred.

Reader validation requirements in stage0:

1. Reject duplicate keys.
2. Require `target` to be one of: `x86_64-linux-elf`, `x86_64-windows-pe`.
3. Require `entry_symbol` to be one of: `main`, `unit`.
4. Require repository-relative `source_path` (no rooted path or `..` traversal).
5. Require `source_sha256` to be a 64-hex digest.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_finobj_roundtrip.ps1` validates deterministic writer output hash, reader decode for Linux+Windows targets and `main/unit` entry symbols, and malformed-object rejection (duplicate key, bad target/entry symbol, invalid source metadata).
2. `tests/run_stage0_suite.ps1` includes finobj conformance checks in `fin test`.

# FIP-0017: Lean Stdlib v0 (No-libc)

- id: FIP-0017
- address: fin://fip/FIP-0017
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0009", "FIP-0012"]
- target_release: M6
- discussion: TBD
- implementation:
  - std/README.md
  - tests/conformance/verify_stdlib_contract.ps1
  - tests/run_stage0_suite.ps1
- acceptance:
  - Stdlib API conformance and runtime ABI tests pass.

## Summary

Defines portable minimal standard library surface and constraints.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 implementation delta:

1. `std/README.md` publishes the lean v0 module plan for `core`, `result`, `sys`, `io`, `time`, `alloc`, `thread`, and `channel`.
2. The stdlib contract explicitly routes OS-facing behavior through Fin runtime shims and the target ABI contracts from FIP-0009 and FIP-0012.
3. `tests/conformance/verify_stdlib_contract.ps1` gates the stage0 stdlib plan so required module entries, FIP linkage, and no-libc wording cannot silently drift.
4. Runtime stdlib implementation and executable API conformance remain pending; this status is InProgress, not Implemented.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Current compatibility notes:

1. No stable stdlib runtime API is exposed by this slice.
2. The module names are reserved planning surface for FIP-0017 and should only change through FIP-linked compatibility notes.
3. The no-libc contract is normative for future stdlib implementations.

## Test Plan

Current checks:

1. `tests/conformance/verify_stdlib_contract.ps1` validates the documented module plan, FIP implementation linkage, and no-libc policy wording.
2. `tests/run_stage0_suite.ps1` includes the stdlib contract check in `fin test`.

Full acceptance still requires stdlib API conformance and runtime ABI tests.

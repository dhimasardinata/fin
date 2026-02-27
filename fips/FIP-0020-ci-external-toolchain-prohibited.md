# FIP-0020: CI Gate: External Toolchain Prohibited

- id: FIP-0020
- address: fin://fip/FIP-0020
- status: Implemented
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0002", "FIP-0018"]
- target_release: M0
- discussion: TBD
- implementation:
  - ci/forbid_external_toolchain.ps1
  - tests/reproducibility/verify_toolchain_policy_gate.ps1
  - tests/run_stage0_suite.ps1
  - .github/workflows/ci.yml
- acceptance:
  - CI job fails on disallowed command invocation patterns.

## Summary

Defines mandatory CI checks that block external toolchain usage.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current CI policy gate:

1. Workflow files are scanned for disallowed external toolchain command patterns.
2. Matches fail the check unless explicitly allow-tagged (`fin-ci-allow-external`).
3. Gate runs in CI and in local `fin doctor`/policy scripts.

Disallowed classes include compiler, linker, and assembler commands (`gcc/clang/ld/as/nasm/...`).

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. CI step runs `./ci/forbid_external_toolchain.ps1`.
2. `tests/reproducibility/verify_toolchain_policy_gate.ps1` validates fail/pass behavior on synthetic workflow content.
3. `tests/run_stage0_suite.ps1` includes gate self-check.

# FIP-0015: Unified fin CLI Contract

- id: FIP-0015
- address: fin://fip/FIP-0015
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0002"]
- target_release: M3
- discussion: TBD
- implementation:
  - cmd/fin/fin.ps1
  - fin.ps1
  - cmd/fin/README.md
- acceptance:
  - CLI behavior tests pass for all mandatory commands.

## Summary

Defines command-line UX and command semantics.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Bootstrap implementation is available as a PowerShell shim until the native `fin` binary exists.

Current commands:

1. `doctor`: executes policy and seed checks.
2. `emit-elf-exit0`: runs the FIP-0010 stage0 emitter and verifier.

This preserves forward compatibility with the planned unified CLI contract while enabling immediate policy enforcement.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `./fin.ps1 doctor` succeeds on compliant repos.
2. `./fin.ps1 emit-elf-exit0` produces and verifies a valid ELF sample.

Remaining command set (`init/build/run/test/fmt/doc/pkg`) remains scheduled.

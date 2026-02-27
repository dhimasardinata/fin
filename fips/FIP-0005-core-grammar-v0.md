# FIP-0005: Core Grammar v0

- id: FIP-0005
- address: fin://fip/FIP-0005
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0004"]
- target_release: M2
- discussion: TBD
- implementation:
  - compiler/finc/stage0/parse_main_exit.ps1
  - tests/conformance/verify_stage0_grammar.ps1
- acceptance:
  - Parser conformance suite passes canonical grammar fixtures.

## Summary

Defines tokens, grammar, expressions, statements, and declarations.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 subset grammar:

`fn main() { exit(<u8>) }`

Accepted stage0 tolerances:

1. Arbitrary whitespace/newlines.
2. Optional semicolon after `exit(...)`.
3. Exit code range constrained to `0..255`.

This subset is intentionally minimal and acts as the first executable parser checkpoint.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates valid and invalid fixtures.
2. Parser must reject non-`main` entrypoint patterns for stage0 subset.

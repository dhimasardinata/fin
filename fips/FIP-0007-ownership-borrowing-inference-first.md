# FIP-0007: Ownership and Borrowing (Inference-First)

- id: FIP-0007
- address: fin://fip/FIP-0007
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0006"]
- target_release: M2
- discussion: TBD
- implementation:
  - compiler/finc/stage0/parse_main_exit.ps1
  - tests/conformance/verify_stage0_grammar.ps1
  - tests/conformance/fixtures/invalid_borrow_reference_expr.fn
  - tests/conformance/fixtures/invalid_dereference_expr.fn
  - tests/conformance/fixtures/invalid_borrow_type_annotation.fn
- acceptance:
  - Safety suite catches use-after-free and double-free classes.

## Summary

Defines memory safety model with low annotation burden.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 implementation delta:

1. Stage0 bootstrap model is copy-only value semantics; ownership/borrowing operators are not part of executable grammar yet.
2. Expression parser now rejects borrow/reference syntax (`&expr`) with deterministic diagnostics.
3. Expression parser now rejects dereference syntax (`*expr`) with deterministic diagnostics.
4. Type-annotation parser rejects ownership/borrowing-prefixed type annotations in stage0 bootstrap.
5. This slice creates an explicit parser/test gate so unsupported ownership syntax is rejected deterministically while ownership inference design is still evolving.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` asserts parse failures for `invalid_borrow_reference_expr.fn`, `invalid_dereference_expr.fn`, and `invalid_borrow_type_annotation.fn`.
2. `tests/run_stage0_suite.ps1` invokes `tests/conformance/verify_stage0_grammar.ps1` in the stage0 aggregate suite.

Acceptance criteria listed above remain normative for Implemented status.

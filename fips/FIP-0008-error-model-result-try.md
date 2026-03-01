# FIP-0008: Error Model (Result + try)

- id: FIP-0008
- address: fin://fip/FIP-0008
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0006"]
- target_release: M2
- discussion: TBD
- implementation:
  - compiler/finc/stage0/parse_main_exit.ps1
  - tests/conformance/verify_stage0_grammar.ps1
  - tests/conformance/fixtures/main_exit_try_literal.fn
  - tests/conformance/fixtures/main_exit_try_identifier.fn
  - tests/conformance/fixtures/invalid_try_missing_expression.fn
  - tests/run_stage0_suite.ps1
- acceptance:
  - Error-flow conformance suite passes without hidden control flow.

## Summary

Defines recoverable error behavior and propagation semantics.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 implementation delta:

1. Stage0 expression parser accepts bootstrap `try(<expr>)` form.
2. Stage0 `try(<expr>)` currently forwards inner expression value/type (no hidden control flow).
3. Empty `try()` is rejected with deterministic parse diagnostics.
4. `Result<T,E>` construction/propagation semantics remain pending; this slice establishes parser/test scaffolding for `try` syntax.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates valid `try(<expr>)` literal/identifier cases and rejects empty `try()` case.
2. `tests/run_stage0_suite.ps1` compiles and executes `try` fixtures in aggregated stage0 flow.

Acceptance criteria listed above remain normative for Implemented status.

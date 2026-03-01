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
  - tests/conformance/fixtures/main_exit_try_ok_result.fn
  - tests/conformance/fixtures/main_exit_try_move_ok_result.fn
  - tests/conformance/fixtures/main_exit_result_typed_binding.fn
  - tests/conformance/fixtures/main_exit_err_unused.fn
  - tests/conformance/fixtures/main_exit_err_binding_ok_path.fn
  - tests/conformance/fixtures/invalid_try_missing_expression.fn
  - tests/conformance/fixtures/invalid_ok_missing_expression.fn
  - tests/conformance/fixtures/invalid_err_missing_expression.fn
  - tests/conformance/fixtures/invalid_try_err_result.fn
  - tests/conformance/fixtures/invalid_try_err_identifier.fn
  - tests/conformance/fixtures/invalid_try_move_err_identifier.fn
  - tests/conformance/fixtures/invalid_try_non_result_literal.fn
  - tests/conformance/fixtures/invalid_try_non_result_identifier.fn
  - tests/run_stage0_suite.ps1
- acceptance:
  - Error-flow conformance suite passes without hidden control flow.

## Summary

Defines recoverable error behavior and propagation semantics.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 implementation delta:

1. Stage0 expression parser accepts bootstrap `try(<expr>)`, `ok(<expr>)`, and `err(<expr>)` forms.
2. Stage0 bootstrap result type is restricted to `Result<u8,u8>` wrappers from `ok/err`.
3. Stage0 `try(...)` is restricted to `Result<u8,u8>` inputs in this phase; non-result inputs are rejected deterministically.
4. Stage0 `Result<u8,u8>` local binding annotations are accepted and interoperable with `try`.
5. Stage0 `try(ok(<expr>))` (or `try` of known-ok result binding) unwraps to `u8`.
6. Stage0 `err(<expr>)` result construction is accepted for explicit error-value modeling without implicit control transfer.
7. Stage0 `try(err(<expr>))` (including err-state identifier paths) is explicitly rejected to avoid hidden control flow in this bootstrap phase.
8. Empty `try()`, `ok()`, and `err()` are rejected with explicit deterministic diagnostics (`try/ok/err (...) requires an inner expression`) backed by conformance fixtures.
9. Stage0 `try(move(<ident>))` is supported for moved `Result<u8,u8>` values, with `ok` moved-state unwrapping and deterministic rejection for moved err-state results (no hidden control flow).
10. Full `Result<T,E>` construction/propagation semantics remain pending; this slice establishes parser/test scaffolding and explicit bootstrap constraints.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates valid bootstrap `ok/err/try` cases (including explicit `Result<u8,u8>` local annotations and `try(move(<result-ident>))` on `ok` state) and rejects empty `try()/ok()/err()`, `try(err(...))` (including moved err-state identifier paths), and `try` on non-result inputs (literal and identifier), with deterministic message checks for hidden-control-flow and type constraints.
2. `tests/run_stage0_suite.ps1` compiles and executes `ok/err/try` fixtures (including move-wrapped result `try`) in aggregated stage0 flow.

Acceptance criteria listed above remain normative for Implemented status.

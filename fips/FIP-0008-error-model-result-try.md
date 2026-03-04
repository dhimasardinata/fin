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
  - tests/conformance/fixtures/main_exit_try_ok_move_u8.fn
  - tests/conformance/fixtures/main_exit_err_move_u8.fn
  - tests/conformance/fixtures/main_exit_try_move_ok_move_u8.fn
  - tests/conformance/fixtures/main_exit_try_move_result_reinit_move_again.fn
  - tests/conformance/fixtures/main_exit_try_move_result_reinit_drop_reinit.fn
  - tests/conformance/fixtures/main_exit_try_move_other_result_assign.fn
  - tests/conformance/fixtures/main_exit_try_move_ok_nested_wrapper.fn
  - tests/conformance/fixtures/main_exit_err_try_move_ok_identifier.fn
  - tests/conformance/fixtures/main_exit_err_try_move_ok_reinit_source.fn
  - tests/conformance/fixtures/main_exit_ok_try_move_ok_reinit_source.fn
  - tests/conformance/fixtures/main_exit_ok_try_move_ok_reinit_drop_reinit_source.fn
  - tests/conformance/fixtures/main_exit_err_try_move_ok_reinit_drop_reinit_source.fn
  - tests/conformance/fixtures/main_exit_try_postfix_ok_result.fn
  - tests/conformance/fixtures/main_exit_try_postfix_move_ok_result.fn
  - tests/conformance/fixtures/main_exit_try_postfix_arithmetic.fn
  - tests/conformance/fixtures/main_exit_result_typed_binding.fn
  - tests/conformance/fixtures/main_exit_err_unused.fn
  - tests/conformance/fixtures/main_exit_err_binding_ok_path.fn
  - tests/conformance/fixtures/invalid_try_missing_expression.fn
  - tests/conformance/fixtures/invalid_ok_missing_expression.fn
  - tests/conformance/fixtures/invalid_err_missing_expression.fn
  - tests/conformance/fixtures/invalid_ok_non_u8_identifier.fn
  - tests/conformance/fixtures/invalid_err_non_u8_identifier.fn
  - tests/conformance/fixtures/invalid_ok_move_non_u8_identifier.fn
  - tests/conformance/fixtures/invalid_err_move_non_u8_identifier.fn
  - tests/conformance/fixtures/invalid_try_err_result.fn
  - tests/conformance/fixtures/invalid_try_err_identifier.fn
  - tests/conformance/fixtures/invalid_try_move_err_identifier.fn
  - tests/conformance/fixtures/invalid_ok_try_err_identifier.fn
  - tests/conformance/fixtures/invalid_err_try_err_identifier.fn
  - tests/conformance/fixtures/invalid_ok_try_move_err_identifier.fn
  - tests/conformance/fixtures/invalid_err_try_move_err_identifier.fn
  - tests/conformance/fixtures/invalid_err_try_move_use_after_move_source.fn
  - tests/conformance/fixtures/invalid_ok_try_move_use_after_move_source.fn
  - tests/conformance/fixtures/invalid_ok_try_move_drop_after_move_source.fn
  - tests/conformance/fixtures/invalid_err_try_move_drop_after_move_source.fn
  - tests/conformance/fixtures/invalid_ok_try_move_assign_after_move_immutable_source.fn
  - tests/conformance/fixtures/invalid_err_try_move_assign_after_move_immutable_source.fn
  - tests/conformance/fixtures/invalid_try_non_result_literal.fn
  - tests/conformance/fixtures/invalid_try_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_ok_try_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_err_try_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_try_move_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_ok_try_move_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_err_try_move_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_try_move_result_use_after_move.fn
  - tests/conformance/fixtures/invalid_try_move_result_assign_after_move_immutable.fn
  - tests/conformance/fixtures/invalid_try_move_result_drop_after_move.fn
  - tests/conformance/fixtures/invalid_try_move_result_self_assignment.fn
  - tests/conformance/fixtures/invalid_try_postfix_missing_operand.fn
  - tests/conformance/fixtures/invalid_try_postfix_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_try_postfix_err_identifier.fn
  - tests/conformance/fixtures/invalid_try_postfix_move_use_after_move_source.fn
  - tests/run_stage0_suite.ps1
- acceptance:
  - Error-flow conformance suite passes without hidden control flow.

## Summary

Defines recoverable error behavior and propagation semantics.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 implementation delta:

1. Stage0 expression parser accepts bootstrap `try(<expr>)`, postfix unwrap `<expr>?`, `ok(<expr>)`, and `err(<expr>)` forms.
2. Stage0 bootstrap result type is restricted to `Result<u8,u8>` wrappers from `ok/err`.
3. Stage0 `try(...)` is restricted to `Result<u8,u8>` inputs in this phase; non-result inputs are rejected deterministically.
4. Stage0 `Result<u8,u8>` local binding annotations are accepted and interoperable with `try`.
5. Stage0 `try(ok(<expr>))` (or `try` of known-ok result binding) unwraps to `u8`.
6. Stage0 `err(<expr>)` result construction is accepted for explicit error-value modeling without implicit control transfer.
7. Stage0 `try(err(<expr>))` (including err-state identifier paths) is explicitly rejected to avoid hidden control flow in this bootstrap phase.
8. Empty `try()`, `ok()`, and `err()` are rejected with explicit deterministic diagnostics (`try/ok/err (...) requires an inner expression`) backed by conformance fixtures.
9. `ok(...)` and `err(...)` reject non-`u8` inner expressions (for example `Result<u8,u8>` identifiers, including moved identifier forms) with deterministic type diagnostics.
10. Stage0 `try(move(<ident>))` is supported for moved `Result<u8,u8>` values, with `ok` moved-state unwrapping and deterministic rejection for moved err-state results (no hidden control flow); the moved result binding is consumed, later use is rejected deterministically, mutable bindings may be explicitly re-initialized before subsequent moved unwraps, lifecycle transition guards (including drop-after-move rejection) remain enforced after moved unwrap consumption, assignment-target self-consumption hazards through `try(move(...))` are rejected deterministically, and wrapper composition (for example `ok(try(move(<result-ident>)))` or `err(try(move(<result-ident>)))`) preserves the same moved-state constraints including source-binding consumption and post-move lifecycle checks.
11. `ok(...)`/`err(...)` inner expressions obey stage0 ownership semantics; `ok(move(<u8-ident>))` and `err(move(<u8-ident>))` are valid and consume the source binding, and moved-state effects remain observable by later lifecycle checks.
12. Stage0 postfix unwrap `<expr>?` mirrors `try(<expr>)` constraints: operand must be `Result<u8,u8>`, known `ok` state unwraps to `u8`, known `err` state is rejected to avoid hidden control flow, and non-result operands are rejected deterministically.
13. Full `Result<T,E>` construction/propagation semantics remain pending; this slice establishes parser/test scaffolding and explicit bootstrap constraints.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates valid bootstrap `ok/err/try` cases (including explicit `Result<u8,u8>` local annotations, `try(move(<result-ident>))` on `ok` state, nested `ok(move(<u8-ident>))` then `try(move(<result-ident>))`, mutable re-init then second moved unwrap on result bindings, mutable re-init/drop/re-init chains before subsequent moved unwraps, assignment from `ok(try(move(<other-result-ident>)))` into a different mutable result binding, wrapper composition `ok(try(move(<result-ident>)))` and `err(try(move(<result-ident>)))` on moved `ok` result paths, nested `ok(try(move(<result-ident>)))` and `err(try(move(<result-ident>)))` source re-init after consumption including `reinit -> drop -> reinit` transitions, `ok(move(<u8-ident>))` unwrapped by `try`, `err(move(<u8-ident>))` ownership propagation, and postfix unwrap forms `<expr>?`) and rejects empty `try()/ok()/err()`, non-`u8` `ok/err` inner expressions (including moved `Result<u8,u8>` identifier wrappers), `try(err(...))` (including non-move and moved err-state identifier paths and nested wrapper forms), `try` on non-result inputs (literal, identifier, moved non-result identifier, and nested wrapper forms with both non-move and moved non-result identifiers), invalid postfix unwraps (missing operand, non-result operand, and err-state operand), post-unwrap use-after-move on consumed result bindings (including `try(move(...))` and `move(<ident>)?` paths), immutable re-init after moved unwrap consumption (including nested wrapper source paths), drop-after-move after moved unwrap consumption (including nested `ok(try(move(...)))` and `err(try(move(...)))` source paths), and self-target assignment hazards through `try(move(<same-ident>))`, with deterministic message checks for hidden-control-flow and type constraints.
2. `tests/run_stage0_suite.ps1` compiles and executes `ok/err/try` fixtures (including move-wrapped result `try`, nested move chains, re-init plus second moved unwrap, re-init/drop/re-init moved-result chains, cross-binding assignment through moved `try` unwrap, wrapper composition through `ok(try(move(<result-ident>)))` and `err(try(move(<result-ident>)))`, nested source re-init after `ok(try(move(...)))` and `err(try(move(...)))` including `reinit -> drop -> reinit` chain, `ok(move(<u8-ident>))`, `err(move(<u8-ident>))`, and postfix unwrap `<expr>?` paths) in aggregated stage0 flow.

Acceptance criteria listed above remain normative for Implemented status.

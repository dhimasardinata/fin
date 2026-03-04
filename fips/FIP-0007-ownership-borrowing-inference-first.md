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
  - tests/run_stage0_suite.ps1
  - tests/conformance/fixtures/main_drop_unused.fn
  - tests/conformance/fixtures/main_move_binding.fn
  - tests/conformance/fixtures/main_move_reinit_var.fn
  - tests/conformance/fixtures/main_drop_reinit_var.fn
  - tests/conformance/fixtures/main_move_reinit_move_again.fn
  - tests/conformance/fixtures/main_drop_reinit_move.fn
  - tests/conformance/fixtures/main_drop_reinit_drop_reinit.fn
  - tests/conformance/fixtures/main_result_move_reinit_var.fn
  - tests/conformance/fixtures/main_result_drop_reinit_var.fn
  - tests/conformance/fixtures/main_result_drop_reinit_move.fn
  - tests/conformance/fixtures/main_result_move_reinit_move_again.fn
  - tests/conformance/fixtures/main_result_drop_reinit_drop_reinit.fn
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
  - tests/conformance/fixtures/main_exit_try_ok_move_u8.fn
  - tests/conformance/fixtures/main_exit_err_move_u8.fn
  - tests/conformance/fixtures/main_exit_if_move_then_selected.fn
  - tests/conformance/fixtures/main_exit_if_move_else_selected.fn
  - tests/conformance/fixtures/main_exit_logic_and_short_circuit_move_rhs.fn
  - tests/conformance/fixtures/main_exit_logic_or_short_circuit_move_rhs.fn
  - tests/conformance/fixtures/main_exit_borrow_deref.fn
  - tests/conformance/fixtures/main_exit_borrow_typed_u8.fn
  - tests/conformance/fixtures/main_exit_borrow_result_try.fn
  - tests/conformance/fixtures/main_exit_borrow_reflects_reassign.fn
  - tests/conformance/fixtures/invalid_result_use_after_drop.fn
  - tests/conformance/fixtures/invalid_result_use_after_move.fn
  - tests/conformance/fixtures/invalid_result_assign_after_drop_immutable.fn
  - tests/conformance/fixtures/invalid_result_assign_after_move_immutable.fn
  - tests/conformance/fixtures/invalid_result_drop_after_move.fn
  - tests/conformance/fixtures/invalid_result_move_after_drop.fn
  - tests/conformance/fixtures/invalid_result_double_drop.fn
  - tests/conformance/fixtures/invalid_result_double_move.fn
  - tests/conformance/fixtures/invalid_result_use_after_redrop.fn
  - tests/conformance/fixtures/invalid_result_self_move_assignment.fn
  - tests/conformance/fixtures/invalid_try_move_result_use_after_move.fn
  - tests/conformance/fixtures/invalid_try_move_result_assign_after_move_immutable.fn
  - tests/conformance/fixtures/invalid_try_move_result_drop_after_move.fn
  - tests/conformance/fixtures/invalid_try_move_result_self_assignment.fn
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
  - tests/conformance/fixtures/invalid_ok_try_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_err_try_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_ok_try_move_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_err_try_move_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_result_drop_undefined.fn
  - tests/conformance/fixtures/invalid_result_move_undefined.fn
  - tests/conformance/fixtures/invalid_borrow_reference_expr.fn
  - tests/conformance/fixtures/invalid_dereference_expr.fn
  - tests/conformance/fixtures/invalid_borrow_type_annotation.fn
  - tests/conformance/fixtures/invalid_borrow_after_move.fn
  - tests/conformance/fixtures/invalid_dereference_missing_operand.fn
  - tests/conformance/fixtures/invalid_dereference_non_reference.fn
  - tests/conformance/fixtures/invalid_use_after_drop.fn
  - tests/conformance/fixtures/invalid_use_after_redrop.fn
  - tests/conformance/fixtures/invalid_double_drop.fn
  - tests/conformance/fixtures/invalid_assign_after_drop.fn
  - tests/conformance/fixtures/invalid_assign_after_move_immutable.fn
  - tests/conformance/fixtures/invalid_drop_undefined.fn
  - tests/conformance/fixtures/invalid_use_after_move.fn
  - tests/conformance/fixtures/invalid_use_after_move_inside_ok.fn
  - tests/conformance/fixtures/invalid_use_after_move_inside_err.fn
  - tests/conformance/fixtures/invalid_logic_and_use_after_move_rhs_selected.fn
  - tests/conformance/fixtures/invalid_logic_or_use_after_move_rhs_selected.fn
  - tests/conformance/fixtures/invalid_logic_not_use_after_move.fn
  - tests/conformance/fixtures/invalid_double_move.fn
  - tests/conformance/fixtures/invalid_move_undefined.fn
  - tests/conformance/fixtures/invalid_drop_after_move.fn
  - tests/conformance/fixtures/invalid_move_after_drop.fn
  - tests/conformance/fixtures/invalid_self_move_assignment.fn
- acceptance:
  - Safety suite catches use-after-free and double-free classes.

## Summary

Defines memory safety model with low annotation burden.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 implementation delta:

1. Stage0 bootstrap model is lifecycle-tracked value semantics with minimal executable borrow support; ownership operations are explicit and deterministic.
2. Stage0 parser now supports `drop(<ident>)` as an explicit lifetime-end marker for bindings in parser semantics.
3. Stage0 parser now supports `move(<ident>)` expression form as explicit ownership transfer (source becomes unavailable after move).
4. Binding lifecycle is tracked explicitly as `alive`, `moved`, or `dropped` in parser semantics for deterministic safety diagnostics.
5. Identifier use after `drop(<ident>)` or `move(<ident>)` is rejected deterministically with distinct diagnostics.
6. Double-drop and double-move are rejected deterministically.
7. `drop(<ident>)` after move and `move(<ident>)` after drop are rejected deterministically.
8. Self-move assignment hazards are rejected deterministically.
9. Moved and dropped mutable bindings can be re-initialized by assignment (lifecycle returns to `alive` after assignment).
10. Moved and dropped immutable bindings reject re-initialization with explicit deterministic diagnostics.
11. Conformance now covers lifecycle transition cycles (`move -> reinit -> move` and `drop -> reinit -> move`) for mutable bindings.
12. Conformance now also covers repeated `drop -> reinit` mutable cycles and post-redrop use rejection.
13. Conformance now covers result-typed mutable lifecycle transitions and cycles (`Result<u8,u8>` with `move/drop -> reinit`, `drop -> reinit -> move`, `move -> reinit -> move`, and repeated `drop -> reinit`).
14. Conformance now also asserts deterministic diagnostics for result-typed lifecycle misuse on immutable and consumed bindings (use-after-drop/move/redrop, assign-after-drop/move-immutable, invalid drop/move transitions, double-drop/move, undefined drop/move, and self-move assignment hazards).
15. Drop/move on undefined identifiers are rejected deterministically.
16. Expression parser supports minimal borrow/reference syntax `&<ident>` and infers reference types (`&u8` and `&Result<u8,u8>` in current stage0 set), while rejecting non-identifier borrow operands deterministically.
17. Expression parser supports dereference syntax `*<expr>` for reference operands, yielding the underlying type, with deterministic rejection for missing operands and non-reference operands.
18. Type-annotation parser accepts borrowing-prefixed binding annotations (`&u8`, `&Result<u8,u8>`) and keeps deterministic mismatch diagnostics when initializer type does not match.
19. Reference bindings carry target metadata; identifier and move reads from references require target lifecycle `alive`, and dereference of references whose targets are moved/dropped is rejected deterministically.
20. Lifecycle tracking propagates through nested expression contexts; move operations nested inside wrappers (for example `ok(move(<ident>))` and `err(move(<ident>))`) still consume the source binding and enforce use-after-move diagnostics.
21. Result-binding moves inside error-model unwrapping paths (for example `try(move(<result-ident>))`) consume the result binding itself, and subsequent identifier use is rejected deterministically.
22. Moved mutable result bindings consumed by `try(move(<result-ident>))` may be re-initialized and consumed again, while moved immutable result bindings reject re-initialization with deterministic diagnostics.
23. Lifecycle transition restrictions remain active after moved unwrap consumption; for example `drop(<ident>)` after `try(move(<result-ident>))` is rejected as drop-after-move until explicit re-initialization occurs on mutable bindings.
24. Assignment-target hazard guards remain active when moved unwraps appear inside assignment expressions; self-target expressions such as `target = ok(try(move(target)))` are rejected deterministically.
25. Nested wrapper composition preserves moved-result constraints; `ok(try(move(<result-ident>)))` and `err(try(move(<result-ident>)))` consume moved inputs consistently and still reject hidden-control-flow err-state paths.
26. Source bindings consumed through nested moved unwrap composition (including `ok(try(move(<result-ident>)))` and `err(try(move(<result-ident>)))`) obey lifecycle checks identically, so use-after-move is rejected and mutable re-initialization restores valid future use.
27. Transition guards remain enforced for nested source-binding paths; for example `drop(<ident>)` after nested `ok(try(move(<ident>)))` or `err(try(move(<ident>)))` consumption is rejected as drop-after-move until mutable re-initialization restores `alive`.
28. Immutable nested source-binding paths keep the same guard behavior; re-initialization assignments after nested `ok(try(move(<ident>)))`/`err(try(move(<ident>)))` consumption are rejected deterministically.
29. Nested wrapper paths also preserve type guards for `try` inputs; non-result identifiers in `ok(try(<ident>))`/`err(try(<ident>))` and non-result moved identifiers in `ok(try(move(<ident>)))`/`err(try(move(<ident>)))` are rejected deterministically with the same `try(...) expects Result<u8,u8>` diagnostics.
30. This slice creates explicit parser/test safety gates while ownership inference and borrow-check semantics are still evolving.
31. Conditional expression selection through `if(cond, then, else)` applies lifecycle transitions from the selected branch while preserving deterministic ownership diagnostics and move semantics in selected branches.
32. Logical short-circuit selection through `&&` and `||` applies lifecycle transitions only for selected RHS evaluation paths; non-selected RHS paths do not consume moved bindings in live state but still run deterministic copied-state type checks.
33. Unary logical-not composition (`!<expr>`) preserves ownership transitions of its evaluated operand; for example `!move(<ident>)` consumes the binding and subsequent use is rejected deterministically.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates `main_drop_unused.fn`, `main_move_binding.fn`, `main_move_reinit_var.fn`, `main_drop_reinit_var.fn`, `main_move_reinit_move_again.fn`, `main_drop_reinit_move.fn`, `main_drop_reinit_drop_reinit.fn`, `main_result_move_reinit_var.fn`, `main_result_drop_reinit_var.fn`, `main_result_drop_reinit_move.fn`, `main_result_move_reinit_move_again.fn`, `main_result_drop_reinit_drop_reinit.fn`, borrow/dereference fixtures (`main_exit_borrow_deref.fn`, `main_exit_borrow_typed_u8.fn`, `main_exit_borrow_result_try.fn`, `main_exit_borrow_reflects_reassign.fn`), and nested-wrapper/unwrap move fixtures `main_exit_try_ok_move_u8.fn`, `main_exit_err_move_u8.fn`, `main_exit_try_move_ok_move_u8.fn`, `main_exit_try_move_result_reinit_move_again.fn`, `main_exit_try_move_result_reinit_drop_reinit.fn`, `main_exit_try_move_other_result_assign.fn`, `main_exit_try_move_ok_nested_wrapper.fn`, `main_exit_err_try_move_ok_identifier.fn`, `main_exit_err_try_move_ok_reinit_source.fn`, `main_exit_ok_try_move_ok_reinit_source.fn`, `main_exit_ok_try_move_ok_reinit_drop_reinit_source.fn`, `main_exit_err_try_move_ok_reinit_drop_reinit_source.fn`, `main_exit_if_move_then_selected.fn`, `main_exit_if_move_else_selected.fn`, `main_exit_logic_and_short_circuit_move_rhs.fn`, and `main_exit_logic_or_short_circuit_move_rhs.fn`; it asserts parse failures for use-after-drop/move/redrop, double-drop/move, drop-after-move, move-after-drop, assign-after-drop-immutable, assign-after-move-immutable, undefined-drop/move, self-move assignment, nested-wrapper use-after-move (`invalid_use_after_move_inside_ok.fn`, `invalid_use_after_move_inside_err.fn`), logical selected-RHS use-after-move (`invalid_logic_and_use_after_move_rhs_selected.fn`, `invalid_logic_or_use_after_move_rhs_selected.fn`), unary-not moved-operand use-after-move (`invalid_logic_not_use_after_move.fn`), post-`try(move(<result-ident>))` use-after-move (`invalid_try_move_result_use_after_move.fn`, `invalid_err_try_move_use_after_move_source.fn`, `invalid_ok_try_move_use_after_move_source.fn`), immutable re-init after moved `try` consumption (`invalid_try_move_result_assign_after_move_immutable.fn`, `invalid_ok_try_move_assign_after_move_immutable_source.fn`, `invalid_err_try_move_assign_after_move_immutable_source.fn`), drop-after-move after moved `try` consumption (`invalid_try_move_result_drop_after_move.fn`, `invalid_ok_try_move_drop_after_move_source.fn`, `invalid_err_try_move_drop_after_move_source.fn`), nested non-result type rejection in wrapper paths for non-move and moved forms (`invalid_ok_try_non_result_identifier.fn`, `invalid_err_try_non_result_identifier.fn`, `invalid_ok_try_move_non_result_identifier.fn`, `invalid_err_try_move_non_result_identifier.fn`), self-target assignment hazards through moved unwraps (`invalid_try_move_result_self_assignment.fn`), nested-wrapper err-state rejection in non-move and moved forms (`invalid_ok_try_err_identifier.fn`, `invalid_err_try_err_identifier.fn`, `invalid_ok_try_move_err_identifier.fn`, `invalid_err_try_move_err_identifier.fn`), and borrow/dereference misuse fixtures (`invalid_borrow_reference_expr.fn`, `invalid_borrow_after_move.fn`, `invalid_dereference_missing_operand.fn`, `invalid_dereference_non_reference.fn`, `invalid_dereference_expr.fn`, `invalid_borrow_type_annotation.fn`) with deterministic message-substring checks for ownership/lifecycle diagnostics.
2. `tests/run_stage0_suite.ps1` invokes `tests/conformance/verify_stage0_grammar.ps1` in the stage0 aggregate suite.

Acceptance criteria listed above remain normative for Implemented status.

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
  - tests/conformance/fixtures/invalid_borrow_reference_expr.fn
  - tests/conformance/fixtures/invalid_dereference_expr.fn
  - tests/conformance/fixtures/invalid_borrow_type_annotation.fn
  - tests/conformance/fixtures/invalid_use_after_drop.fn
  - tests/conformance/fixtures/invalid_use_after_redrop.fn
  - tests/conformance/fixtures/invalid_double_drop.fn
  - tests/conformance/fixtures/invalid_assign_after_drop.fn
  - tests/conformance/fixtures/invalid_assign_after_move_immutable.fn
  - tests/conformance/fixtures/invalid_drop_undefined.fn
  - tests/conformance/fixtures/invalid_use_after_move.fn
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

1. Stage0 bootstrap model is copy-only value semantics; ownership/borrowing operators are not part of executable grammar yet.
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
14. Conformance now also asserts deterministic diagnostics for result-typed lifecycle misuse on immutable and consumed bindings (use-after-drop/move/redrop, assign-after-drop/move-immutable, invalid drop/move transitions, double-drop/move, and self-move assignment hazards).
15. Drop/move on undefined identifiers are rejected deterministically.
16. Expression parser rejects borrow/reference syntax (`&expr`) with deterministic diagnostics.
17. Expression parser rejects dereference syntax (`*expr`) with deterministic diagnostics.
18. Type-annotation parser rejects ownership/borrowing-prefixed type annotations in stage0 bootstrap.
19. Conformance suite now asserts deterministic ownership/lifecycle diagnostics by message substring for use-after-drop/move and invalid transition cases.
20. This slice creates explicit parser/test safety gates while ownership inference and borrow-check semantics are still evolving.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates `main_drop_unused.fn`, `main_move_binding.fn`, `main_move_reinit_var.fn`, `main_drop_reinit_var.fn`, `main_move_reinit_move_again.fn`, `main_drop_reinit_move.fn`, `main_drop_reinit_drop_reinit.fn`, `main_result_move_reinit_var.fn`, `main_result_drop_reinit_var.fn`, `main_result_drop_reinit_move.fn`, `main_result_move_reinit_move_again.fn`, and `main_result_drop_reinit_drop_reinit.fn`; it asserts parse failures for use-after-drop/move/redrop, double-drop/move, drop-after-move, move-after-drop, assign-after-drop-immutable, assign-after-move-immutable, undefined-drop/move, self-move assignment, borrow-reference, dereference, and borrow-type fixtures, including result-typed lifecycle misuse fixtures and repeated-transition misuse fixtures, with message-substring checks for ownership/lifecycle diagnostics.
2. `tests/run_stage0_suite.ps1` invokes `tests/conformance/verify_stage0_grammar.ps1` in the stage0 aggregate suite.

Acceptance criteria listed above remain normative for Implemented status.

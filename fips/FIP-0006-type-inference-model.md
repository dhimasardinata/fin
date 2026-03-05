# FIP-0006: Type Inference Model

- id: FIP-0006
- address: fin://fip/FIP-0006
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0005"]
- target_release: M2
- discussion: TBD
- implementation:
  - compiler/finc/stage0/parse_main_exit.ps1
  - tests/conformance/verify_stage0_grammar.ps1
  - tests/conformance/fixtures/main_exit_typed_u8.fn
  - tests/conformance/fixtures/main_exit_signature_u8.fn
  - tests/conformance/fixtures/main_exit_add_identifier_literal.fn
  - tests/conformance/fixtures/main_exit_mul_precedence.fn
  - tests/conformance/fixtures/main_exit_mod_precedence.fn
  - tests/conformance/fixtures/main_exit_cmp_precedence.fn
  - tests/conformance/fixtures/main_exit_bitwise_precedence.fn
  - tests/conformance/fixtures/main_exit_bitwise_cmp_precedence.fn
  - tests/conformance/fixtures/main_exit_shift_left_literals.fn
  - tests/conformance/fixtures/main_exit_shift_right_literals.fn
  - tests/conformance/fixtures/main_exit_shift_precedence.fn
  - tests/conformance/fixtures/main_exit_shift_cmp_precedence.fn
  - tests/conformance/fixtures/main_exit_bitwise_not_literal.fn
  - tests/conformance/fixtures/main_exit_bitwise_not_bitwise_mix.fn
  - tests/conformance/fixtures/main_exit_bitwise_not_shift_precedence.fn
  - tests/conformance/fixtures/main_exit_hex_literal.fn
  - tests/conformance/fixtures/main_exit_hex_arithmetic.fn
  - tests/conformance/fixtures/main_exit_hex_bitwise_mix.fn
  - tests/conformance/fixtures/main_exit_binary_literal.fn
  - tests/conformance/fixtures/main_exit_binary_arithmetic.fn
  - tests/conformance/fixtures/main_exit_binary_bitwise_mix.fn
  - tests/conformance/fixtures/main_return_literal.fn
  - tests/conformance/fixtures/main_return_expression.fn
  - tests/conformance/fixtures/main_return_parenthesized.fn
  - tests/conformance/fixtures/main_exit_if_cmp_condition.fn
  - tests/conformance/fixtures/main_exit_if_result_branches_try.fn
  - tests/conformance/fixtures/main_exit_logic_precedence.fn
  - tests/conformance/fixtures/main_exit_logic_and_true.fn
  - tests/conformance/fixtures/main_exit_logic_or_true.fn
  - tests/conformance/fixtures/main_exit_logic_not_true.fn
  - tests/conformance/fixtures/main_exit_logic_not_false.fn
  - tests/conformance/fixtures/main_exit_logic_not_eq.fn
  - tests/conformance/fixtures/main_exit_logic_not_or_chain.fn
  - tests/conformance/fixtures/main_exit_logic_not_add_precedence.fn
  - tests/conformance/fixtures/main_exit_bool_true_literal.fn
  - tests/conformance/fixtures/main_exit_bool_false_literal.fn
  - tests/conformance/fixtures/main_exit_bool_if_condition.fn
  - tests/conformance/fixtures/main_exit_bool_logic_mix.fn
  - tests/conformance/fixtures/main_exit_result_typed_binding.fn
  - tests/conformance/fixtures/main_exit_try_postfix_ok_result.fn
  - tests/conformance/fixtures/main_exit_try_postfix_move_ok_result.fn
  - tests/conformance/fixtures/main_exit_try_postfix_arithmetic.fn
  - tests/conformance/fixtures/main_exit_try_space_ok_result.fn
  - tests/conformance/fixtures/main_exit_try_space_move_ok_result.fn
  - tests/conformance/fixtures/main_exit_try_space_arithmetic.fn
  - tests/conformance/fixtures/main_exit_let_unwrap_binding_ok.fn
  - tests/conformance/fixtures/main_exit_let_unwrap_binding_move_ok.fn
  - tests/conformance/fixtures/main_exit_let_unwrap_binding_arithmetic.fn
  - tests/conformance/fixtures/main_exit_unwrap_assignment_ok.fn
  - tests/conformance/fixtures/main_exit_unwrap_assignment_move_ok.fn
  - tests/conformance/fixtures/main_exit_unwrap_assignment_arithmetic.fn
  - tests/conformance/fixtures/main_exit_unwrap_assignment_after_rhs_releases_borrow.fn
  - tests/conformance/fixtures/main_exit_var_unwrap_binding_ok.fn
  - tests/conformance/fixtures/main_exit_var_unwrap_binding_move_ok.fn
  - tests/conformance/fixtures/main_exit_var_unwrap_binding_arithmetic.fn
  - tests/conformance/fixtures/main_exit_borrow_deref.fn
  - tests/conformance/fixtures/main_exit_borrow_typed_u8.fn
  - tests/conformance/fixtures/main_exit_borrow_result_try.fn
  - tests/conformance/fixtures/main_exit_borrow_reflects_reassign.fn
  - tests/conformance/fixtures/main_exit_borrow_drop_ref_then_move.fn
  - tests/conformance/fixtures/main_exit_borrow_drop_ref_then_assign.fn
  - tests/conformance/fixtures/main_exit_assign_after_rhs_releases_borrow.fn
  - tests/conformance/fixtures/main_exit_plus_equals_literal.fn
  - tests/conformance/fixtures/main_exit_plus_equals_after_rhs_releases_borrow.fn
  - tests/conformance/fixtures/main_exit_helper_default_u8.fn
  - tests/conformance/fixtures/main_exit_helper_chain.fn
  - tests/conformance/fixtures/main_exit_helper_result_try.fn
  - tests/conformance/fixtures/main_exit_helper_params_add.fn
  - tests/conformance/fixtures/main_exit_helper_params_result_try.fn
  - tests/conformance/fixtures/invalid_add_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_mul_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_mod_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_cmp_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_bitwise_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_shift_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_shift_left_count_out_of_range.fn
  - tests/conformance/fixtures/invalid_shift_right_count_out_of_range.fn
  - tests/conformance/fixtures/invalid_bitwise_not_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_bitwise_not_missing_operand.fn
  - tests/conformance/fixtures/invalid_hex_literal_non_hex_digit.fn
  - tests/conformance/fixtures/invalid_hex_literal_prefix_only.fn
  - tests/conformance/fixtures/invalid_hex_literal_out_of_range.fn
  - tests/conformance/fixtures/invalid_binary_literal_non_binary_digit.fn
  - tests/conformance/fixtures/invalid_binary_literal_prefix_only.fn
  - tests/conformance/fixtures/invalid_binary_literal_out_of_range.fn
  - tests/conformance/fixtures/invalid_return_non_u8_expression.fn
  - tests/conformance/fixtures/invalid_logic_non_u8_operand_and.fn
  - tests/conformance/fixtures/invalid_logic_non_u8_operand_or_short_circuit.fn
  - tests/conformance/fixtures/invalid_logic_not_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_if_non_u8_condition.fn
  - tests/conformance/fixtures/invalid_if_branch_type_mismatch.fn
  - tests/conformance/fixtures/invalid_try_postfix_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_try_postfix_err_identifier.fn
  - tests/conformance/fixtures/invalid_try_space_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_try_space_err_identifier.fn
  - tests/conformance/fixtures/invalid_let_unwrap_binding_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_let_unwrap_binding_err_identifier.fn
  - tests/conformance/fixtures/invalid_unwrap_assignment_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_unwrap_assignment_err_identifier.fn
  - tests/conformance/fixtures/invalid_unwrap_assignment_immutable_target.fn
  - tests/conformance/fixtures/invalid_unwrap_assignment_after_rhs_still_borrowed.fn
  - tests/conformance/fixtures/invalid_var_unwrap_binding_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_var_unwrap_binding_err_identifier.fn
  - tests/conformance/fixtures/invalid_borrow_reference_expr.fn
  - tests/conformance/fixtures/invalid_dereference_expr.fn
  - tests/conformance/fixtures/invalid_borrow_type_annotation.fn
  - tests/conformance/fixtures/invalid_borrow_after_move.fn
  - tests/conformance/fixtures/invalid_move_while_borrowed.fn
  - tests/conformance/fixtures/invalid_assign_while_borrowed.fn
  - tests/conformance/fixtures/invalid_assign_after_rhs_still_borrowed.fn
  - tests/conformance/fixtures/invalid_plus_equals_immutable_target.fn
  - tests/conformance/fixtures/invalid_plus_equals_non_u8_target.fn
  - tests/conformance/fixtures/invalid_plus_equals_non_u8_expression.fn
  - tests/conformance/fixtures/invalid_plus_equals_overflow.fn
  - tests/conformance/fixtures/invalid_plus_equals_after_rhs_still_borrowed.fn
  - tests/conformance/fixtures/invalid_helper_implicit_u8_result_return.fn
  - tests/conformance/fixtures/invalid_helper_call_type_mismatch.fn
  - tests/conformance/fixtures/invalid_helper_parameter_missing_type.fn
  - tests/conformance/fixtures/invalid_helper_parameter_reference_type.fn
  - tests/conformance/fixtures/invalid_dereference_missing_operand.fn
  - tests/conformance/fixtures/invalid_dereference_non_reference.fn
  - tests/conformance/fixtures/invalid_result_return_annotation.fn
  - tests/conformance/fixtures/invalid_result_annotation_mismatch.fn
  - tests/conformance/fixtures/invalid_unsupported_result_annotation.fn
  - tests/conformance/fixtures/invalid_unsupported_type_annotation.fn
  - tests/conformance/fixtures/invalid_unsupported_return_annotation.fn
  - tests/run_stage0_suite.ps1
- acceptance:
  - Inference test corpus passes with stable diagnostics.

## Summary

Defines local inference and boundary type annotation requirements.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 implementation delta:

1. Local binding inference is active for stage0 expressions (`u8` literals in decimal/hex/binary forms, boolean literals `true`/`false`, and identifiers).
2. Optional explicit annotation is accepted on bindings:
   - `let <ident>: u8 = <expr>`
   - `var <ident>: u8 = <expr>`
   - `let <ident>: Result<u8,u8> = <expr>`
   - `var <ident>: Result<u8,u8> = <expr>`
   - `let <ident>: &u8 = <expr>`
   - `let <ident>: &Result<u8,u8> = <expr>`
3. Stage0 parser validates annotation set and currently accepts `u8`, `Result<u8,u8>`, `&u8`, and `&Result<u8,u8>` on bindings.
4. Unsupported annotations are rejected with deterministic parse diagnostics.
5. Assignment and terminal expression validation (`exit(...)` and `return`) uses inferred/declared type metadata (stage0 currently `u8` and `Result<u8,u8>` for locals; entrypoint return remains `u8`).
6. Optional entrypoint boundary annotation is accepted on stage0 signature:
   - `fn main() -> u8 { ... }`
7. Unsupported entrypoint return annotations are rejected with deterministic parse diagnostics.
8. `fn main() -> Result<u8,u8>` is explicitly rejected in stage0 with deterministic boundary diagnostic; entrypoint return remains `u8` only.
9. Conformance now asserts deterministic message substrings for type mismatch and unsupported type/return annotations.
10. Stage0 arithmetic, comparison, shift, bitwise, and logical operator typing is enforced in inference paths: `+`/`-`/`*`/`/`/`%`/`==`/`!=`/`<`/`<=`/`>`/`>=`/`<<`/`>>`/`&`/`^`/`|`/`!`/`~`/`&&`/`||` require inferred `u8` operands and reject non-`u8` inferred types deterministically; decimal, hexadecimal, and binary literals infer to `u8` values, boolean literals `true`/`false` infer to `u8` values `1`/`0`; comparison/logical expressions infer normalized `u8` predicate values (`0`/`1`); shift/bitwise expressions infer direct `u8` value results, with shift count range enforcement (`0..7`), shift precedence between additive arithmetic and comparisons, bitwise precedence `| < ^ < &` below comparison/shift and above logical operators, and unary `~` inference to `u8` complement values.
11. Stage0 bootstrap unwrap inference supports `try(<expr>)`, prefix `try <expr>`, and postfix `<expr>?`: operand type must infer to `Result<u8,u8>`, `ok` state unwrap infers to `u8`, `err` state is rejected deterministically in bootstrap mode, and non-result operands are rejected deterministically.
12. Stage0 unwrap-binding sugar `let <ident> ?= <expr>` infers the binding type from unwrapped value (`u8` in current bootstrap set) and reuses prefix-unwrap constraints/diagnostics because it desugars to `let <ident> = try <expr>`.
13. Stage0 mutable-declaration unwrap-binding sugar `var <ident> ?= <expr>` infers declaration type from the unwrapped value while preserving `var` mutability semantics, and reuses prefix-unwrap constraints/diagnostics because it desugars to `var <ident> = try <expr>`.
14. Stage0 mutable unwrap-assignment sugar `<ident> ?= <expr>` reuses assignment target typing and lifecycle checks while inferring the RHS through prefix unwrap semantics (`<ident> = try <expr>`), including deterministic rejection for immutable targets, non-result RHS, err-state RHS, and active-borrow conflicts that remain after RHS evaluation.
15. Stage0 mutable compound assignment `<ident> += <expr>` requires an alive mutable `u8` target, infers the RHS through normal expression typing, reuses post-RHS assignment hazard checks, and rejects non-`u8` targets, non-`u8` RHS values, overflow, and active-borrow conflicts deterministically.
16. Stage0 conditional inference in `if(cond, then, else)` enforces `u8` condition typing and exact then/else branch type matching; the expression type is inferred from matched branch type (`u8` or `Result<u8,u8>` in current stage0 set).
17. Logical short-circuit still preserves deterministic operand typing rules in inference: non-selected RHS branches do not mutate runtime lifecycle state but are type-checked using copied state to preserve deterministic diagnostics.
18. Stage0 borrow/dereference inference supports `&<ident>` and `*<expr>`: borrow infers reference type (`&u8` or `&Result<u8,u8>`), dereference expects reference operands and infers underlying value type (`u8` or `Result<u8,u8>`), dereference rejects consumed reference targets deterministically when source lifecycle is not `alive`, and non-reference target assignment/move/drop is rejected while active borrows exist (for assignment, borrow conflicts are checked after RHS evaluation so RHS-owned borrow release can succeed).
19. Stage0 helper parameter boundaries require explicit type annotations; current helper parameter types are restricted to `u8` and `Result<u8,u8>`, `main` remains zero-argument, and callee parameter bindings enter scope as immutable alive locals with those declared boundary types.
20. Stage0 helper calls `<ident>([<expr>, ...])` infer to the callee boundary type: omitted helper return boundaries default to `u8`, explicit helper return boundaries currently allow `u8` or `Result<u8,u8>`, helper argument expressions are type-checked left-to-right against parameter boundaries, and helper call expressions propagate the inferred return type into surrounding arithmetic, assignment, and unwrap checks.
21. Helper functions with omitted return boundaries reject non-`u8` terminal expressions deterministically, keeping stage0 boundary inference explicit without requiring extra type syntax on the common `u8` path.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates typed binding/signature success, `Result<u8,u8>` typed binding success, reference typed-binding success (`&u8`, `&Result<u8,u8>`), helper boundary inference success (`main_exit_helper_default_u8.fn`, `main_exit_helper_chain.fn`, `main_exit_helper_result_try.fn`, `main_exit_helper_params_add.fn`, `main_exit_helper_params_result_try.fn`), `Result<u8,u8>` entrypoint return rejection, annotation mismatch failure, unsupported annotation rejection, helper-parameter annotation/type rejection (`invalid_helper_parameter_missing_type.fn`, `invalid_helper_parameter_reference_type.fn`, `invalid_helper_call_type_mismatch.fn`), non-`u8` inferred operator-operand rejection (`invalid_add_non_u8_operand.fn`, `invalid_mul_non_u8_operand.fn`, `invalid_mod_non_u8_operand.fn`, `invalid_cmp_non_u8_operand.fn`, `invalid_shift_non_u8_operand.fn`, `invalid_bitwise_non_u8_operand.fn`, `invalid_bitwise_not_non_u8_operand.fn`, `invalid_logic_non_u8_operand_and.fn`, `invalid_logic_non_u8_operand_or_short_circuit.fn`, `invalid_logic_not_non_u8_operand.fn`), shift-count range rejection (`invalid_shift_left_count_out_of_range.fn`, `invalid_shift_right_count_out_of_range.fn`), missing unary `~` operand rejection (`invalid_bitwise_not_missing_operand.fn`), malformed/out-of-range hex/binary literal rejection (`invalid_hex_literal_non_hex_digit.fn`, `invalid_hex_literal_prefix_only.fn`, `invalid_hex_literal_out_of_range.fn`, `invalid_binary_literal_non_binary_digit.fn`, `invalid_binary_literal_prefix_only.fn`, `invalid_binary_literal_out_of_range.fn`), non-`u8` return-expression rejection (`invalid_return_non_u8_expression.fn`, `invalid_helper_implicit_u8_result_return.fn`), non-`u8` `if` condition rejection (`invalid_if_non_u8_condition.fn`), `if` branch-type mismatch rejection (`invalid_if_branch_type_mismatch.fn`), bootstrap-unwrap inference rejection for non-result/err-state operands across prefix and postfix forms (`invalid_try_postfix_non_result_identifier.fn`, `invalid_try_postfix_err_identifier.fn`, `invalid_try_space_non_result_identifier.fn`, `invalid_try_space_err_identifier.fn`), unwrap-binding sugar inference rejection for non-result/err-state RHS (`invalid_let_unwrap_binding_non_result_identifier.fn`, `invalid_let_unwrap_binding_err_identifier.fn`, `invalid_var_unwrap_binding_non_result_identifier.fn`, `invalid_var_unwrap_binding_err_identifier.fn`), unwrap-assignment sugar inference/target rejection (`invalid_unwrap_assignment_non_result_identifier.fn`, `invalid_unwrap_assignment_err_identifier.fn`, `invalid_unwrap_assignment_immutable_target.fn`, `invalid_unwrap_assignment_after_rhs_still_borrowed.fn`), compound-assignment inference/target rejection (`invalid_plus_equals_immutable_target.fn`, `invalid_plus_equals_non_u8_target.fn`, `invalid_plus_equals_non_u8_expression.fn`, `invalid_plus_equals_overflow.fn`, `invalid_plus_equals_after_rhs_still_borrowed.fn`), and borrow/dereference inference rejections (`invalid_borrow_reference_expr.fn`, `invalid_borrow_after_move.fn`, `invalid_move_while_borrowed.fn`, `invalid_assign_while_borrowed.fn`, `invalid_assign_after_rhs_still_borrowed.fn`, `invalid_dereference_missing_operand.fn`, `invalid_dereference_non_reference.fn`, `invalid_dereference_expr.fn`, `invalid_borrow_type_annotation.fn`) with deterministic message-substring assertions.
2. `tests/run_stage0_suite.ps1` compiles typed fixtures (`main_exit_typed_u8.fn`, `main_exit_signature_u8.fn`, `main_exit_result_typed_binding.fn`, `main_exit_add_identifier_literal.fn`, `main_exit_mul_precedence.fn`, `main_exit_mod_precedence.fn`, `main_exit_cmp_precedence.fn`, `main_exit_shift_left_literals.fn`, `main_exit_shift_right_literals.fn`, `main_exit_shift_precedence.fn`, `main_exit_shift_cmp_precedence.fn`, `main_exit_bitwise_not_literal.fn`, `main_exit_bitwise_not_bitwise_mix.fn`, `main_exit_bitwise_not_shift_precedence.fn`, `main_exit_hex_literal.fn`, `main_exit_hex_arithmetic.fn`, `main_exit_hex_bitwise_mix.fn`, `main_exit_binary_literal.fn`, `main_exit_binary_arithmetic.fn`, `main_exit_binary_bitwise_mix.fn`, `main_return_literal.fn`, `main_return_expression.fn`, `main_return_parenthesized.fn`, `main_exit_bitwise_precedence.fn`, `main_exit_bitwise_cmp_precedence.fn`, `main_exit_logic_precedence.fn`, `main_exit_logic_and_true.fn`, `main_exit_logic_or_true.fn`, `main_exit_logic_not_true.fn`, `main_exit_logic_not_false.fn`, `main_exit_logic_not_eq.fn`, `main_exit_logic_not_or_chain.fn`, `main_exit_logic_not_add_precedence.fn`, `main_exit_bool_true_literal.fn`, `main_exit_bool_false_literal.fn`, `main_exit_bool_if_condition.fn`, `main_exit_bool_logic_mix.fn`, `main_exit_if_cmp_condition.fn`, `main_exit_if_result_branches_try.fn`, `main_exit_try_postfix_ok_result.fn`, `main_exit_try_postfix_move_ok_result.fn`, `main_exit_try_postfix_arithmetic.fn`, `main_exit_try_space_ok_result.fn`, `main_exit_try_space_move_ok_result.fn`, `main_exit_try_space_arithmetic.fn`, `main_exit_let_unwrap_binding_ok.fn`, `main_exit_let_unwrap_binding_move_ok.fn`, `main_exit_let_unwrap_binding_arithmetic.fn`, `main_exit_var_unwrap_binding_ok.fn`, `main_exit_var_unwrap_binding_move_ok.fn`, `main_exit_var_unwrap_binding_arithmetic.fn`, `main_exit_unwrap_assignment_ok.fn`, `main_exit_unwrap_assignment_move_ok.fn`, `main_exit_unwrap_assignment_arithmetic.fn`, `main_exit_unwrap_assignment_after_rhs_releases_borrow.fn`, `main_exit_plus_equals_literal.fn`, `main_exit_plus_equals_after_rhs_releases_borrow.fn`, `main_exit_helper_default_u8.fn`, `main_exit_helper_chain.fn`, `main_exit_helper_result_try.fn`, `main_exit_helper_params_add.fn`, `main_exit_helper_params_result_try.fn`, `main_exit_borrow_deref.fn`, `main_exit_borrow_typed_u8.fn`, `main_exit_borrow_result_try.fn`, `main_exit_borrow_reflects_reassign.fn`, `main_exit_borrow_drop_ref_then_move.fn`, `main_exit_borrow_drop_ref_then_assign.fn`, `main_exit_assign_after_rhs_releases_borrow.fn`) in aggregated stage0 flow.

Acceptance criteria listed above remain normative for Implemented status.



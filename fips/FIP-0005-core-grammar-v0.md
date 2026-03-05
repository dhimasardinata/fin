# FIP-0005: Core Grammar v0

- id: FIP-0005
- address: fin://fip/FIP-0005
- status: Implemented
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0004"]
- target_release: M2
- discussion: TBD
- implementation:
  - compiler/finc/stage0/parse_main_exit.ps1
  - tests/conformance/verify_stage0_grammar.ps1
  - tests/run_stage0_suite.ps1
  - tests/conformance/fixtures/main_exit_add_literals.fn
  - tests/conformance/fixtures/main_exit_add_identifier_literal.fn
  - tests/conformance/fixtures/main_exit_sub_literals.fn
  - tests/conformance/fixtures/main_exit_mul_literals.fn
  - tests/conformance/fixtures/main_exit_div_literals.fn
  - tests/conformance/fixtures/main_exit_mod_literals.fn
  - tests/conformance/fixtures/main_exit_mod_precedence.fn
  - tests/conformance/fixtures/main_exit_mod_grouped.fn
  - tests/conformance/fixtures/main_exit_bitwise_and_literals.fn
  - tests/conformance/fixtures/main_exit_bitwise_or_literals.fn
  - tests/conformance/fixtures/main_exit_bitwise_xor_literals.fn
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
  - tests/conformance/fixtures/main_exit_mul_precedence.fn
  - tests/conformance/fixtures/main_exit_mul_grouped.fn
  - tests/conformance/fixtures/main_exit_cmp_eq_true.fn
  - tests/conformance/fixtures/main_exit_cmp_lt_true.fn
  - tests/conformance/fixtures/main_exit_cmp_precedence.fn
  - tests/conformance/fixtures/main_exit_cmp_ge_false_bias.fn
  - tests/conformance/fixtures/main_exit_if_true_literal.fn
  - tests/conformance/fixtures/main_exit_if_false_literal.fn
  - tests/conformance/fixtures/main_exit_if_cmp_condition.fn
  - tests/conformance/fixtures/main_exit_if_move_then_selected.fn
  - tests/conformance/fixtures/main_exit_if_move_else_selected.fn
  - tests/conformance/fixtures/main_exit_if_result_branches_try.fn
  - tests/conformance/fixtures/main_exit_logic_and_true.fn
  - tests/conformance/fixtures/main_exit_logic_or_true.fn
  - tests/conformance/fixtures/main_exit_logic_precedence.fn
  - tests/conformance/fixtures/main_exit_logic_and_short_circuit_move_rhs.fn
  - tests/conformance/fixtures/main_exit_logic_or_short_circuit_move_rhs.fn
  - tests/conformance/fixtures/main_exit_logic_not_true.fn
  - tests/conformance/fixtures/main_exit_logic_not_false.fn
  - tests/conformance/fixtures/main_exit_logic_not_eq.fn
  - tests/conformance/fixtures/main_exit_logic_not_or_chain.fn
  - tests/conformance/fixtures/main_exit_logic_not_add_precedence.fn
  - tests/conformance/fixtures/main_exit_bool_true_literal.fn
  - tests/conformance/fixtures/main_exit_bool_false_literal.fn
  - tests/conformance/fixtures/main_exit_bool_if_condition.fn
  - tests/conformance/fixtures/main_exit_bool_logic_mix.fn
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
  - tests/conformance/fixtures/invalid_add_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_add_overflow.fn
  - tests/conformance/fixtures/invalid_sub_underflow.fn
  - tests/conformance/fixtures/invalid_mul_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_mul_overflow.fn
  - tests/conformance/fixtures/invalid_div_by_zero.fn
  - tests/conformance/fixtures/invalid_mod_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_mod_by_zero.fn
  - tests/conformance/fixtures/invalid_mod_missing_rhs.fn
  - tests/conformance/fixtures/invalid_bitwise_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_bitwise_missing_rhs.fn
  - tests/conformance/fixtures/invalid_shift_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_shift_missing_rhs.fn
  - tests/conformance/fixtures/invalid_shift_left_count_out_of_range.fn
  - tests/conformance/fixtures/invalid_shift_right_count_out_of_range.fn
  - tests/conformance/fixtures/invalid_shift_left_overflow.fn
  - tests/conformance/fixtures/invalid_bitwise_not_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_bitwise_not_missing_operand.fn
  - tests/conformance/fixtures/invalid_hex_literal_non_hex_digit.fn
  - tests/conformance/fixtures/invalid_hex_literal_prefix_only.fn
  - tests/conformance/fixtures/invalid_hex_literal_out_of_range.fn
  - tests/conformance/fixtures/invalid_binary_literal_non_binary_digit.fn
  - tests/conformance/fixtures/invalid_binary_literal_prefix_only.fn
  - tests/conformance/fixtures/invalid_binary_literal_out_of_range.fn
  - tests/conformance/fixtures/invalid_return_missing_expression.fn
  - tests/conformance/fixtures/invalid_return_empty_parenthesized.fn
  - tests/conformance/fixtures/invalid_return_non_u8_expression.fn
  - tests/conformance/fixtures/invalid_statement_after_return.fn
  - tests/conformance/fixtures/invalid_empty_parenthesized_expr.fn
  - tests/conformance/fixtures/invalid_cmp_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_cmp_missing_rhs.fn
  - tests/conformance/fixtures/invalid_if_missing_argument.fn
  - tests/conformance/fixtures/invalid_if_empty_argument.fn
  - tests/conformance/fixtures/invalid_if_non_u8_condition.fn
  - tests/conformance/fixtures/invalid_if_branch_type_mismatch.fn
  - tests/conformance/fixtures/invalid_logic_non_u8_operand_and.fn
  - tests/conformance/fixtures/invalid_logic_non_u8_operand_or_short_circuit.fn
  - tests/conformance/fixtures/invalid_logic_missing_rhs.fn
  - tests/conformance/fixtures/invalid_logic_and_use_after_move_rhs_selected.fn
  - tests/conformance/fixtures/invalid_logic_or_use_after_move_rhs_selected.fn
  - tests/conformance/fixtures/invalid_logic_not_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_logic_not_missing_operand.fn
  - tests/conformance/fixtures/invalid_logic_not_use_after_move.fn
  - tests/conformance/fixtures/invalid_bool_keyword_binding_true.fn
  - tests/conformance/fixtures/invalid_bool_keyword_assignment_true.fn
  - tests/conformance/fixtures/invalid_try_postfix_missing_operand.fn
  - tests/conformance/fixtures/invalid_try_postfix_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_try_postfix_err_identifier.fn
  - tests/conformance/fixtures/invalid_try_postfix_move_use_after_move_source.fn
  - tests/conformance/fixtures/invalid_try_space_missing_expression.fn
  - tests/conformance/fixtures/invalid_try_space_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_try_space_err_identifier.fn
  - tests/conformance/fixtures/invalid_try_space_move_use_after_move_source.fn
  - tests/conformance/fixtures/invalid_let_unwrap_binding_missing_expression.fn
  - tests/conformance/fixtures/invalid_let_unwrap_binding_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_let_unwrap_binding_err_identifier.fn
  - tests/conformance/fixtures/invalid_let_unwrap_binding_move_use_after_move_source.fn
  - tests/conformance/fixtures/invalid_unwrap_assignment_missing_expression.fn
  - tests/conformance/fixtures/invalid_unwrap_assignment_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_unwrap_assignment_err_identifier.fn
  - tests/conformance/fixtures/invalid_unwrap_assignment_immutable_target.fn
  - tests/conformance/fixtures/invalid_unwrap_assignment_move_use_after_move_source.fn
  - tests/conformance/fixtures/invalid_unwrap_assignment_after_rhs_still_borrowed.fn
  - tests/conformance/fixtures/invalid_var_unwrap_binding_missing_expression.fn
  - tests/conformance/fixtures/invalid_var_unwrap_binding_non_result_identifier.fn
  - tests/conformance/fixtures/invalid_var_unwrap_binding_err_identifier.fn
  - tests/conformance/fixtures/invalid_var_unwrap_binding_move_use_after_move_source.fn
  - tests/conformance/fixtures/invalid_var_unwrap_binding_duplicate.fn
  - tests/conformance/fixtures/invalid_borrow_reference_expr.fn
  - tests/conformance/fixtures/invalid_dereference_expr.fn
  - tests/conformance/fixtures/invalid_borrow_type_annotation.fn
  - tests/conformance/fixtures/invalid_borrow_after_move.fn
  - tests/conformance/fixtures/invalid_move_while_borrowed.fn
  - tests/conformance/fixtures/invalid_assign_while_borrowed.fn
  - tests/conformance/fixtures/invalid_assign_after_rhs_still_borrowed.fn
  - tests/conformance/fixtures/invalid_plus_equals_missing_expression.fn
  - tests/conformance/fixtures/invalid_plus_equals_immutable_target.fn
  - tests/conformance/fixtures/invalid_plus_equals_non_u8_target.fn
  - tests/conformance/fixtures/invalid_plus_equals_non_u8_expression.fn
  - tests/conformance/fixtures/invalid_plus_equals_overflow.fn
  - tests/conformance/fixtures/invalid_plus_equals_after_rhs_still_borrowed.fn
  - tests/conformance/fixtures/invalid_dereference_missing_operand.fn
  - tests/conformance/fixtures/invalid_dereference_non_reference.fn
- acceptance:
  - Parser conformance suite passes canonical grammar fixtures.

## Summary

Defines tokens, grammar, expressions, statements, and declarations.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 subset grammar:

`fn main() [-> u8] { <stmt>* }`

`<stmt>` (stage0):

1. `let <ident> = <expr>`
2. `var <ident> = <expr>`
3. `let <ident> ?= <expr>` (stage0 bootstrap unwrap-binding sugar; equivalent to `let <ident> = try <expr>`)
4. `var <ident> ?= <expr>` (stage0 mutable-declaration unwrap sugar; equivalent to `var <ident> = try <expr>`)
5. `<ident> ?= <expr>` (stage0 mutable unwrap-assignment sugar; equivalent to `<ident> = try <expr>`)
6. `<ident> += <expr>` (stage0 mutable compound assignment sugar; equivalent to `<ident> = <ident> + <expr>` with current `u8`/lifecycle constraints)
7. `<ident> = <expr>` (only for `var`)
8. `drop(<ident>)`
9. `exit(<expr>)` and `return <expr>` / `return(<expr>)` (terminal statement forms)

`<expr>` (stage0):

1. `<u8-literal>` (`0..255`) with decimal (`42`), hexadecimal (`0x2A`/`0X2A`), and binary (`0b101010`/`0B101010`) forms, plus boolean literal keywords `true` and `false` (stage0 aliases for `1` and `0`)
2. `<ident>`
3. `&<ident>` and `*<expr>` (stage0 minimal borrow/dereference forms)
4. `move(<ident>)` (stage0 bootstrap ownership transfer form)
5. `ok(<expr>)` / `err(<expr>)` (stage0 bootstrap result wrappers)
6. `try(<expr>)`, `try <expr>`, and `<expr>?` (stage0 bootstrap unwrap forms)
7. `!<expr>` and `~<expr>` (stage0 unary forms; `!` yields normalized `u8` predicate `0`/`1`, `~` yields `u8` bitwise complement, and both bind tighter than binary operators)
8. `(<expr>)` (parenthesized expression grouping)
9. `<expr> + <expr>`, `<expr> - <expr>`, `<expr> * <expr>`, `<expr> / <expr>`, and `<expr> % <expr>` (stage0 `u8` arithmetic forms, with `*`/`/`/`%` higher precedence than `+`/`-`)
10. `<expr> == <expr>`, `<expr> != <expr>`, `<expr> < <expr>`, `<expr> <= <expr>`, `<expr> > <expr>`, and `<expr> >= <expr>` (stage0 comparison forms yielding `u8` predicates `0`/`1`, with lower precedence than arithmetic)
11. `<expr> << <expr>` and `<expr> >> <expr>` (stage0 `u8` shift forms; shift counts must be in `0..7`, and shifts are lower precedence than additive/multiplicative arithmetic and higher precedence than comparisons)
12. `<expr> & <expr>`, `<expr> ^ <expr>`, and `<expr> | <expr>` (stage0 `u8` bitwise forms; precedence is `|` lower than `^` lower than `&`, and all three are lower than comparison/shift/arithmetic but higher than logical `&&`/`||`)
13. `if(<expr>, <expr>, <expr>)` (stage0 conditional expression; condition must be `u8`, then/else branches must type-match)
14. `<expr> && <expr>` and `<expr> || <expr>` (stage0 logical forms yielding normalized `u8` predicates `0`/`1`; precedence is `||` lower than `&&`, both lower than bitwise/comparison/shift/arithmetic)

`<type>` (stage0):

1. `u8`
2. `Result<u8,u8>` (binding annotations only; entrypoint return remains `u8` in stage0)
3. `&u8`
4. `&Result<u8,u8>`

Accepted stage0 tolerances:

1. Arbitrary whitespace/newlines.
2. Optional semicolon statement separators.
3. Line comments using `#` and `//`.
4. Entry point restricted to `fn main()` with optional `-> u8` annotation.

This subset is intentionally minimal and acts as the first executable parser checkpoint.

Note: stage0 optional binding type-annotation forms (`let/var <ident>: u8 = <expr>` and `let/var <ident>: Result<u8,u8> = <expr>`) plus optional entrypoint return annotation (`fn main() -> u8`) are introduced under `FIP-0006`. Stage0 bootstrap unwrap syntax (`try(<expr>)`, prefix `try <expr>`, and postfix `<expr>?`) is introduced under `FIP-0008`, where stage0 unwrap inputs are constrained to `Result<u8,u8>`. Stage0 unwrap-binding sugars (`let <ident> ?= <expr>` and `var <ident> ?= <expr>`) desugar to `let/var <ident> = try <expr>` under the same deterministic bootstrap constraints and diagnostics, stage0 mutable unwrap-assignment sugar (`<ident> ?= <expr>`) desugars to `<ident> = try <expr>` under existing mutable-assignment lifecycle and type constraints, and stage0 compound assignment (`<ident> += <expr>`) desugars conceptually to `<ident> = <ident> + <expr>` while preserving the current mutable-assignment hazard model. Stage0 `drop(<ident>)` and `move(<ident>)` bootstrap ownership forms are introduced under `FIP-0007`; stage0 parser semantics now track `alive/moved/dropped` lifecycle states, allow mutable moved/dropped binding re-initialization via assignment, reject immutable moved/dropped binding re-initialization, and support minimal borrow/reference expressions (`&<ident>`) and dereference (`*<expr>`) with deterministic lifecycle diagnostics for non-alive reference targets and active-borrow assignment/move/drop conflicts (assignment conflicts are evaluated after RHS expression evaluation).
Stage0 arithmetic (`+`, `-`, `*`, `/`, `%`), comparison operators, shift operators (`<<`, `>>`), bitwise operators (`&`, `^`, `|`), unary operators (`!`, `~`), binary logical operators (`&&`, `||`), and mutable compound assignment (`+=`) are constrained to `u8` operands, with deterministic rejection for non-`u8` operands, deterministic overflow/underflow checks, explicit division/modulo-by-zero rejection, explicit shift-count range checks (`0..7`) and left-shift overflow rejection, parenthesized grouping support for precedence control, deterministic binary-operator parse errors when operands are missing, explicit unary-operator parse errors when `!` or `~` has no operand, deterministic bootstrap-unwrap parse/type/state diagnostics when prefix `try` has no operand or when prefix/postfix unwrap is applied to unsupported/non-`ok` result inputs, deterministic hexadecimal/binary literal validation (invalid digit rejection, prefix-only `0x`/`0X`/`0b`/`0B` rejection, and range rejection beyond `0..255`), terminal statement parity for `exit(<expr>)` and `return` forms with deterministic missing-expression and post-terminal-statement rejection diagnostics, explicit `if(cond, then, else)` conditional expressions that enforce `u8` conditions plus branch type matching, boolean literal aliases `true`/`false` mapped to `u8` (`1`/`0`), reserved-keyword identifier rejection for `true`/`false`, stage0 shift precedence below additive/multiplicative arithmetic and above comparisons, stage0 bitwise precedence (`| < ^ < &`) below comparison/shift/arithmetic and above logical `&&`/`||`, and short-circuit logical evaluation that preserves side-effect/lifecycle behavior on the non-selected RHS while still enforcing deterministic RHS type checks.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates valid and invalid fixtures for literals, bindings, mutation, and comments, with deterministic message-substring assertions for missing entrypoint, undefined identifier use, and immutable assignment rejection.
2. `tests/conformance/verify_stage0_grammar.ps1` validates stage0 `u8` arithmetic (`+`, `-`, `*`, `/`, `%`), comparisons (`==`, `!=`, `<`, `<=`, `>`, `>=`), shifts (`<<`, `>>`), bitwise operators (`&`, `^`, `|`), unary/binary logical operators (`!`, `~`, `&&`, `||`), bootstrap unwrap forms (`try(<expr>)`, `try <expr>`, and postfix `<expr>?`), unwrap-binding sugars (`let <ident> ?= <expr>` and `var <ident> ?= <expr>`), unwrap-assignment sugar (`<ident> ?= <expr>`), compound assignment (`<ident> += <expr>`), decimal/hexadecimal/binary literals, boolean literals (`true`, `false`), terminal `exit`/`return` forms, parenthesized grouping, and `if(cond, then, else)` with deterministic diagnostics for non-`u8` operands, overflow/underflow, division/modulo-by-zero, shift-count range violations, left-shift overflow, missing binary-operator operands, missing unary `!`/`~` operands, malformed/out-of-range hex/binary literals, missing return expressions, statements after terminal exit/return, empty parenthesized expressions, invalid/missing `if` arguments, non-`u8` conditions, reserved-keyword identifier misuse (`true`/`false`), branch type mismatches, invalid bootstrap unwrap forms, invalid unwrap-binding/unwrap-assignment/compound-assignment forms, and selected-operand ownership misuse in logical expressions.
3. Parser rejects non-`main` entrypoint patterns for stage0 subset.
4. Parser rejects undefined identifiers and assignment to immutable `let` bindings.

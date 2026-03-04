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
3. Stage0 parser validates annotation set and currently accepts `u8` and `Result<u8,u8>` on bindings.
4. Unsupported annotations are rejected with deterministic parse diagnostics.
5. Assignment and terminal expression validation (`exit(...)` and `return`) uses inferred/declared type metadata (stage0 currently `u8` and `Result<u8,u8>` for locals; entrypoint return remains `u8`).
6. Optional entrypoint boundary annotation is accepted on stage0 signature:
   - `fn main() -> u8 { ... }`
7. Unsupported entrypoint return annotations are rejected with deterministic parse diagnostics.
8. `fn main() -> Result<u8,u8>` is explicitly rejected in stage0 with deterministic boundary diagnostic; entrypoint return remains `u8` only.
9. Conformance now asserts deterministic message substrings for type mismatch and unsupported type/return annotations.
10. Stage0 arithmetic, comparison, shift, bitwise, and logical operator typing is enforced in inference paths: `+`/`-`/`*`/`/`/`%`/`==`/`!=`/`<`/`<=`/`>`/`>=`/`<<`/`>>`/`&`/`^`/`|`/`!`/`~`/`&&`/`||` require inferred `u8` operands and reject non-`u8` inferred types deterministically; decimal, hexadecimal, and binary literals infer to `u8` values, boolean literals `true`/`false` infer to `u8` values `1`/`0`; comparison/logical expressions infer normalized `u8` predicate values (`0`/`1`); shift/bitwise expressions infer direct `u8` value results, with shift count range enforcement (`0..7`), shift precedence between additive arithmetic and comparisons, bitwise precedence `| < ^ < &` below comparison/shift and above logical operators, and unary `~` inference to `u8` complement values.
11. Stage0 postfix unwrap (`<expr>?`) inference mirrors `try(<expr>)`: operand type must infer to `Result<u8,u8>`, `ok` state unwrap infers to `u8`, `err` state is rejected deterministically in bootstrap mode, and non-result operands are rejected deterministically.
12. Stage0 conditional inference in `if(cond, then, else)` enforces `u8` condition typing and exact then/else branch type matching; the expression type is inferred from matched branch type (`u8` or `Result<u8,u8>` in current stage0 set).
13. Logical short-circuit still preserves deterministic operand typing rules in inference: non-selected RHS branches do not mutate runtime lifecycle state but are type-checked using copied state to preserve deterministic diagnostics.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates typed binding/signature success, `Result<u8,u8>` typed binding success, `Result<u8,u8>` entrypoint return rejection, annotation mismatch failure, unsupported annotation rejection, non-`u8` inferred operator-operand rejection (`invalid_add_non_u8_operand.fn`, `invalid_mul_non_u8_operand.fn`, `invalid_mod_non_u8_operand.fn`, `invalid_cmp_non_u8_operand.fn`, `invalid_shift_non_u8_operand.fn`, `invalid_bitwise_non_u8_operand.fn`, `invalid_bitwise_not_non_u8_operand.fn`, `invalid_logic_non_u8_operand_and.fn`, `invalid_logic_non_u8_operand_or_short_circuit.fn`, `invalid_logic_not_non_u8_operand.fn`), shift-count range rejection (`invalid_shift_left_count_out_of_range.fn`, `invalid_shift_right_count_out_of_range.fn`), missing unary `~` operand rejection (`invalid_bitwise_not_missing_operand.fn`), malformed/out-of-range hex/binary literal rejection (`invalid_hex_literal_non_hex_digit.fn`, `invalid_hex_literal_prefix_only.fn`, `invalid_hex_literal_out_of_range.fn`, `invalid_binary_literal_non_binary_digit.fn`, `invalid_binary_literal_prefix_only.fn`, `invalid_binary_literal_out_of_range.fn`), non-`u8` return-expression rejection (`invalid_return_non_u8_expression.fn`), non-`u8` `if` condition rejection (`invalid_if_non_u8_condition.fn`), `if` branch-type mismatch rejection (`invalid_if_branch_type_mismatch.fn`), and postfix-unwrap inference rejection for non-result/err-state operands (`invalid_try_postfix_non_result_identifier.fn`, `invalid_try_postfix_err_identifier.fn`) with deterministic message-substring assertions.
2. `tests/run_stage0_suite.ps1` compiles typed fixtures (`main_exit_typed_u8.fn`, `main_exit_signature_u8.fn`, `main_exit_result_typed_binding.fn`, `main_exit_add_identifier_literal.fn`, `main_exit_mul_precedence.fn`, `main_exit_mod_precedence.fn`, `main_exit_cmp_precedence.fn`, `main_exit_shift_left_literals.fn`, `main_exit_shift_right_literals.fn`, `main_exit_shift_precedence.fn`, `main_exit_shift_cmp_precedence.fn`, `main_exit_bitwise_not_literal.fn`, `main_exit_bitwise_not_bitwise_mix.fn`, `main_exit_bitwise_not_shift_precedence.fn`, `main_exit_hex_literal.fn`, `main_exit_hex_arithmetic.fn`, `main_exit_hex_bitwise_mix.fn`, `main_exit_binary_literal.fn`, `main_exit_binary_arithmetic.fn`, `main_exit_binary_bitwise_mix.fn`, `main_return_literal.fn`, `main_return_expression.fn`, `main_return_parenthesized.fn`, `main_exit_bitwise_precedence.fn`, `main_exit_bitwise_cmp_precedence.fn`, `main_exit_logic_precedence.fn`, `main_exit_logic_and_true.fn`, `main_exit_logic_or_true.fn`, `main_exit_logic_not_true.fn`, `main_exit_logic_not_false.fn`, `main_exit_logic_not_eq.fn`, `main_exit_logic_not_or_chain.fn`, `main_exit_logic_not_add_precedence.fn`, `main_exit_bool_true_literal.fn`, `main_exit_bool_false_literal.fn`, `main_exit_bool_if_condition.fn`, `main_exit_bool_logic_mix.fn`, `main_exit_if_cmp_condition.fn`, `main_exit_if_result_branches_try.fn`, `main_exit_try_postfix_ok_result.fn`, `main_exit_try_postfix_move_ok_result.fn`, `main_exit_try_postfix_arithmetic.fn`) in aggregated stage0 flow.

Acceptance criteria listed above remain normative for Implemented status.

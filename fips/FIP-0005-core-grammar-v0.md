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
  - tests/conformance/fixtures/main_exit_mul_precedence.fn
  - tests/conformance/fixtures/main_exit_mul_grouped.fn
  - tests/conformance/fixtures/main_exit_cmp_eq_true.fn
  - tests/conformance/fixtures/main_exit_cmp_lt_true.fn
  - tests/conformance/fixtures/main_exit_cmp_precedence.fn
  - tests/conformance/fixtures/main_exit_cmp_ge_false_bias.fn
  - tests/conformance/fixtures/invalid_add_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_add_overflow.fn
  - tests/conformance/fixtures/invalid_sub_underflow.fn
  - tests/conformance/fixtures/invalid_mul_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_mul_overflow.fn
  - tests/conformance/fixtures/invalid_div_by_zero.fn
  - tests/conformance/fixtures/invalid_empty_parenthesized_expr.fn
  - tests/conformance/fixtures/invalid_cmp_non_u8_operand.fn
  - tests/conformance/fixtures/invalid_cmp_missing_rhs.fn
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
3. `<ident> = <expr>` (only for `var`)
4. `drop(<ident>)`
5. `exit(<expr>)` (terminal statement)

`<expr>` (stage0):

1. `<u8-literal>` (`0..255`)
2. `<ident>`
3. `move(<ident>)` (stage0 bootstrap ownership transfer form)
4. `ok(<expr>)` / `err(<expr>)` (stage0 bootstrap result wrappers)
5. `try(<expr>)` (stage0 bootstrap form)
6. `(<expr>)` (parenthesized expression grouping)
7. `<expr> + <expr>`, `<expr> - <expr>`, `<expr> * <expr>`, and `<expr> / <expr>` (stage0 `u8` arithmetic forms, with `*`/`/` higher precedence than `+`/`-`)
8. `<expr> == <expr>`, `<expr> != <expr>`, `<expr> < <expr>`, `<expr> <= <expr>`, `<expr> > <expr>`, and `<expr> >= <expr>` (stage0 comparison forms yielding `u8` predicates `0`/`1`, with lower precedence than arithmetic)

`<type>` (stage0):

1. `u8`
2. `Result<u8,u8>` (binding annotations only; entrypoint return remains `u8` in stage0)

Accepted stage0 tolerances:

1. Arbitrary whitespace/newlines.
2. Optional semicolon statement separators.
3. Line comments using `#` and `//`.
4. Entry point restricted to `fn main()` with optional `-> u8` annotation.

This subset is intentionally minimal and acts as the first executable parser checkpoint.

Note: stage0 optional binding type-annotation forms (`let/var <ident>: u8 = <expr>` and `let/var <ident>: Result<u8,u8> = <expr>`) plus optional entrypoint return annotation (`fn main() -> u8`) are introduced under `FIP-0006`. Stage0 bootstrap `try(<expr>)` syntax is introduced under `FIP-0008`, where stage0 `try` is constrained to `Result<u8,u8>` inputs. Stage0 `drop(<ident>)` and `move(<ident>)` bootstrap ownership forms are introduced under `FIP-0007`; stage0 parser semantics now track `alive/moved/dropped` lifecycle states, allow mutable moved/dropped binding re-initialization via assignment, reject immutable moved/dropped binding re-initialization, and continue to reject ownership/borrowing syntax (`&`, `*`) until inference-first ownership semantics are implemented.
Stage0 arithmetic (`+`, `-`, `*`, `/`) and comparison operators are constrained to `u8` operands, with deterministic rejection for non-`u8` operands, deterministic overflow/underflow checks, explicit division-by-zero rejection, parenthesized grouping support for precedence control, and deterministic comparison parse errors when operands are missing.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates valid and invalid fixtures for literals, bindings, mutation, and comments, with deterministic message-substring assertions for missing entrypoint, undefined identifier use, and immutable assignment rejection.
2. `tests/conformance/verify_stage0_grammar.ps1` validates stage0 `u8` arithmetic (`+`, `-`, `*`, `/`), comparisons (`==`, `!=`, `<`, `<=`, `>`, `>=`), and parenthesized grouping with deterministic diagnostics for non-`u8` operands, overflow/underflow, division-by-zero, missing comparison operands, and empty parenthesized expressions.
3. Parser rejects non-`main` entrypoint patterns for stage0 subset.
4. Parser rejects undefined identifiers and assignment to immutable `let` bindings.

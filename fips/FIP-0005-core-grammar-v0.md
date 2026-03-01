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
4. `exit(<expr>)` (terminal statement)

`<expr>` (stage0):

1. `<u8-literal>` (`0..255`)
2. `<ident>`
3. `ok(<expr>)` / `err(<expr>)` (stage0 bootstrap result wrappers)
4. `try(<expr>)` (stage0 bootstrap form)

`<type>` (stage0):

1. `u8`
2. `Result<u8,u8>` (binding annotations only; entrypoint return remains `u8` in stage0)

Accepted stage0 tolerances:

1. Arbitrary whitespace/newlines.
2. Optional semicolon statement separators.
3. Line comments using `#` and `//`.
4. Entry point restricted to `fn main()` with optional `-> u8` annotation.

This subset is intentionally minimal and acts as the first executable parser checkpoint.

Note: stage0 optional binding type-annotation forms (`let/var <ident>: u8 = <expr>` and `let/var <ident>: Result<u8,u8> = <expr>`) plus optional entrypoint return annotation (`fn main() -> u8`) are introduced under `FIP-0006`. Stage0 bootstrap `try(<expr>)` syntax is introduced under `FIP-0008`, where stage0 `try` is constrained to `Result<u8,u8>` inputs. Ownership/borrowing syntax (`&`, `*`) is explicitly rejected in stage0 under `FIP-0007` until inference-first ownership semantics are implemented.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates valid and invalid fixtures for literals, bindings, mutation, and comments.
2. Parser rejects non-`main` entrypoint patterns for stage0 subset.
3. Parser rejects undefined identifiers and assignment to immutable `let` bindings.

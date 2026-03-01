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
  - tests/conformance/fixtures/main_exit_result_typed_binding.fn
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

1. Local binding inference is active for stage0 expressions (`u8` literals and identifiers).
2. Optional explicit annotation is accepted on bindings:
   - `let <ident>: u8 = <expr>`
   - `var <ident>: u8 = <expr>`
   - `let <ident>: Result<u8,u8> = <expr>`
   - `var <ident>: Result<u8,u8> = <expr>`
3. Stage0 parser validates annotation set and currently accepts `u8` and `Result<u8,u8>` on bindings.
4. Unsupported annotations are rejected with deterministic parse diagnostics.
5. Assignment and `exit(...)` expression validation uses inferred/declared type metadata (stage0 currently `u8` and `Result<u8,u8>` for locals; entrypoint return remains `u8`).
6. Optional entrypoint boundary annotation is accepted on stage0 signature:
   - `fn main() -> u8 { ... }`
7. Unsupported entrypoint return annotations are rejected with deterministic parse diagnostics.
8. `fn main() -> Result<u8,u8>` is explicitly rejected in stage0 with deterministic boundary diagnostic; entrypoint return remains `u8` only.
9. Conformance now asserts deterministic message substrings for type mismatch and unsupported type/return annotations.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates typed binding/signature success, `Result<u8,u8>` typed binding success, `Result<u8,u8>` entrypoint return rejection, annotation mismatch failure, and unsupported annotation rejection with deterministic message-substring assertions.
2. `tests/run_stage0_suite.ps1` compiles typed fixtures (`main_exit_typed_u8.fn`, `main_exit_signature_u8.fn`, `main_exit_result_typed_binding.fn`) in aggregated stage0 flow.

Acceptance criteria listed above remain normative for Implemented status.

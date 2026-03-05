# FIP-0004: Source and Module Model for .fn

- id: FIP-0004
- address: fin://fip/FIP-0004
- status: InProgress
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0001"]
- target_release: M0
- discussion: TBD
- implementation:
  - compiler/finc/stage0/parse_main_exit.ps1
  - compiler/finc/stage0/format_main_exit.ps1
  - compiler/finc/stage0/doc_main_exit.ps1
  - compiler/finc/stage0/README.md
  - tests/conformance/verify_stage0_grammar.ps1
  - tests/run_stage0_suite.ps1
  - tests/integration/verify_fmt.ps1
  - tests/conformance/fixtures/main_exit_helper_default_u8.fn
  - tests/conformance/fixtures/main_exit_helper_chain.fn
  - tests/conformance/fixtures/main_exit_helper_result_try.fn
  - tests/conformance/fixtures/invalid_function_call_with_args.fn
  - tests/conformance/fixtures/invalid_undefined_function_call.fn
  - tests/conformance/fixtures/invalid_duplicate_function.fn
  - tests/conformance/fixtures/invalid_recursive_function_call.fn
  - tests/conformance/fixtures/invalid_helper_exit_statement.fn
  - tests/conformance/fixtures/invalid_helper_implicit_u8_result_return.fn
- acceptance:
  - Spec section and examples for module layout are published.

## Summary

Defines source file layout, module boundaries, and naming rules.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Current stage0 implementation delta:

1. One `.fn` source file may contain multiple top-level function declarations.
2. Stage0 currently supports only zero-argument function signatures: `fn <name>() [-> <type>] { ... }`.
3. Exactly one `fn main()` entrypoint is required per source file.
4. Top-level helper declarations may appear before or after `main`; parser resolves them across the file before execution.
5. Helper calls are available as expressions using `<ident>()`.
6. Helper functions must terminate with `return <expr>`; `exit(<expr>)` remains entrypoint-only and is rejected outside `main`.
7. Omitted helper return types default to the `u8` boundary in stage0; explicit helper return annotations currently allow `u8` and `Result<u8,u8>`.
8. Reference-returning helper boundaries are intentionally deferred until later ownership/model slices.
9. Recursive helper calls, including mutual recursion, are rejected deterministically in stage0 bootstrap to keep execution and diagnostics explicit.
10. Formatter safety is non-lossy for multi-function stage0 sources until structured helper formatting lands.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Current stage0 compatibility notes:

1. Existing single-`main` sources remain valid unchanged.
2. Multi-function sources are an additive extension to the file model.
3. `fin fmt` retains canonical collapse for single-function stage0 inputs but preserves multi-function sources to avoid helper erasure until a structured formatter exists.

## Test Plan

Current checks:

1. `tests/conformance/verify_stage0_grammar.ps1` validates multi-function success cases, helper call resolution, helper result-return + `?` usage, and deterministic rejection for undefined helper calls, call arguments, duplicate functions, recursive calls, helper-only `exit(...)`, and implicit-`u8` helper return mismatches.
2. `tests/run_stage0_suite.ps1` compiles helper-call stage0 fixtures in the aggregated build flow.
3. `tests/integration/verify_fmt.ps1` confirms `fin fmt` does not erase multi-function stage0 sources.

# Fin Language Specification (Living)

## Version

- Spec track: v0 living spec.
- Source of truth: this repository.

## Design Principles

The language charter is tracked by `FIP-0001` and this living specification is
the primary artifact that keeps the charter visible in day-to-day design work.

1. Zero-cost abstraction.
2. Explicit performance model.
3. Minimal syntax and low typing overhead.
4. Strong safety with inference-first ergonomics.
5. Deterministic and reproducible builds.
6. Full-independent build pipeline.

## Language Direction (v0 Targets)

- File extension: `.fn`.
- Function form: `fn name(args) -> Type { ... }`.
- Binding forms: `let` (immutable), `var` (mutable).
- Control flow target: `if`, then `match`, `for`, and `while`.
- Error flow target: `Result<T, E>` and `try`.

## Implemented Stage0 Surface

Stage0 is intentionally smaller than the full v0 target surface:

- Top-level `fn main()` and typed helper functions with `u8` or `Result<u8,u8>` value parameters.
- Entry point returns `u8`; helpers may return `u8` or `Result<u8,u8>`.
- `let`, `var`, assignment, compound `+=`, unwrap binding/assignment sugar (`?=`), nested block statements, lexical shadowing, statement-form `if`, and statement-form `while`.
- `u8`, `Result<u8,u8>`, `&u8`, and `&Result<u8,u8>` annotations.
- Decimal, hexadecimal, binary, and boolean literals (`true` => `1`, `false` => `0`).
- Arithmetic, comparison, bitwise, shift, logical, unary, grouped, and conditional expressions over stage0 `u8` values.
- `ok(...)`, `err(...)`, `try(...)`, prefix `try <expr>`, and postfix `<expr>?` bootstrap result forms.
- Stage0 ownership/borrowing forms: `move(...)`, `drop(...)`, `&<ident>`, and `*<expr>`.
- Terminal `exit(...)` and `return <expr>` statements.

`match`, `for`, full generic `Result<T,E>` propagation, and the full module model remain proposal-tracked targets outside the current stage0 subset.

The current source/module layout is documented in `docs/source-module-model.md`.

## Type and Safety Model

- Local type inference by default.
- Explicit types at public boundaries.
- Ownership and borrowing with inference-first defaults.
- No GC in v0.

## Runtime Baseline

- No libc dependency in normal runtime path.
- OS ABI/syscall-facing runtime shims.

## Target Order

1. Linux x86_64 (ELF)
2. Windows x64 (PE)

## Artifact Strategy

- Stage0 direct executable emission for Linux ELF and Windows PE.
- Stage0 `finobj` + `finld` pipeline for deterministic minimal multi-object linking.
- Later milestones extend the object/link model toward full multi-unit compilation.

## Tooling Contract

The bootstrap shim implements the unified `fin` CLI contract:

- `fin init`
- `fin build`
- `fin run`
- `fin test`
- `fin fmt`
- `fin doc`
- `fin pkg add`
- `fin pkg publish`
- `fin doctor`

Detailed contracts live in `FIP-0015`.

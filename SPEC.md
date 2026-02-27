# Fin Language Specification (Living)

## Version

- Spec track: v0 living spec.
- Source of truth: this repository.

## Design Principles

1. Zero-cost abstraction.
2. Explicit performance model.
3. Minimal syntax and low typing overhead.
4. Strong safety with inference-first ergonomics.
5. Deterministic and reproducible builds.
6. Full-independent build pipeline.

## Syntax Surface (v0 Targets)

- File extension: `.fn`.
- Function form: `fn name(args) -> Type { ... }`.
- Binding forms: `let` (immutable), `var` (mutable).
- Control flow: `if`, `match`, `for`, `while`.
- Error flow: `Result<T, E>` and `try`.

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

- Early: direct executable emission.
- Later: `finobj` + `finld` for multi-unit linking.

## Tooling Contract

Unified `fin` CLI planned commands:

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

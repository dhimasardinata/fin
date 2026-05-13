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

Stage0 inference currently covers the bootstrap value set used by executable
fixtures: `u8`, `Result<u8,u8>`, `&u8`, and `&Result<u8,u8>`.
Local `let` and `var` bindings may omit annotations when the initializer
infers one of those supported types. Explicit local annotations are accepted
for the same set and reject mismatched initializers deterministically.

The stage0 entrypoint boundary is `fn main() -> u8`; omitting the return type
keeps the same `u8` boundary. Helper parameters require explicit boundary
types. Helper returns default to `u8` when omitted, and explicit helper returns
currently accept `u8` or `Result<u8,u8>`.

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

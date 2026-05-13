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

## Source and Module Layout

Stage0 uses one `.fn` file as the executable source unit. A source unit must
contain exactly one zero-argument `fn main()` entrypoint. The entrypoint may
appear before or after helper functions, and helper names are resolved across
the whole file before execution.

The current stage0 module boundary is intentionally single-file. Cross-file
modules, imports, packages as module namespaces, and public/private visibility
are later milestones. Within a file, helper functions are the first reusable
unit:

- `main` is the only function allowed to call `exit(...)`.
- Helper functions terminate with `return <expr>`.
- Helper parameters require explicit boundary types.
- Omitted helper return types default to `u8`.
- Explicit helper return types currently allow `u8` and `Result<u8,u8>`.
- Helper recursion, including mutual recursion, is rejected in stage0.

Example single-entry source:

```fin
fn main() {
  exit(7)
}
```

Example helper before `main`:

```fin
fn add(lhs: u8, rhs: u8) -> u8 {
  return lhs + rhs
}

fn main() {
  exit(add(80, 83))
}
```

Example helper after `main`:

```fin
fn main() {
  exit(later())
}

fn later() -> u8 {
  return 173
}
```

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

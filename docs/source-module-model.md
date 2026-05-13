# Source and Module Model

This document records the current Stage0 source layout for `FIP-0004`.

## Stage0 Layout

Stage0 uses one `.fn` source file as the compilation unit. The conventional package entry file is:

```text
src/main.fn
```

A Stage0 source file may contain multiple top-level functions:

- exactly one zero-argument `fn main()` entrypoint is required;
- helper functions may appear before or after `main`;
- helper parameters must use explicit value annotations;
- helper return annotations may be omitted for `u8`, or written as `-> u8` or `-> Result<u8,u8>`;
- `exit(...)` is entrypoint-only;
- helper functions terminate with `return <expr>`;
- recursive helper calls are rejected in Stage0.

The full multi-file module system, imports, visibility, and package source graph are later milestones. Stage0 keeps the module boundary deliberately narrow so parser, type, ownership, and object/link evidence stay deterministic.

## Example

[`examples/stage0/source_module_layout/main.fn`](../examples/stage0/source_module_layout/main.fn) is the checked source-layout example. It demonstrates:

- `main` plus helper functions in one file;
- a helper declared after `main`;
- typed helper parameters;
- `Result<u8,u8>` helper return;
- unwrap-binding sugar through `?=`.

Build it with either Stage0 pipeline:

```powershell
./fin.ps1 build --src examples/stage0/source_module_layout/main.fn --out artifacts/source-module-example
./fin.ps1 build --src examples/stage0/source_module_layout/main.fn --out artifacts/source-module-example-finobj --pipeline finobj
```

The example exits with code `43`.

# Fin Charter

Canonical FIP: `FIP-0001`.

## Goals

- Build a full-independent native programming language using the `.fn` extension.
- Keep abstractions zero-cost and the performance model explicit.
- Keep syntax small, readable, and low-typing.
- Favor inference-first safety for types, ownership, borrowing, and error flow.
- Produce deterministic and reproducible native artifacts.
- Keep normal build paths free from external compiler, assembler, and linker tools.

## Non-Goals

- Fin is not a wrapper around C, LLVM, GCC, or platform vendor toolchains.
- Fin does not depend on libc as the baseline runtime contract.
- Fin does not optimize for language feature breadth before bootstrap trust, determinism, and native output are auditable.
- Fin does not hide control flow, ownership transfer, or reproducibility-impacting behavior behind implicit tooling.

## Product Philosophy

- Prefer a small auditable core over broad unchecked surface area.
- Make bootstrap and release trust visible in repository files and CI.
- Keep the default developer workflow simple enough for one command to explain what happened.
- Add language surface only when it can be specified, tested, and reproduced in the stage plan.

## Non-Negotiable Constraints

1. External toolchain use is forbidden in normal build paths.
2. Bootstrap trust starts from an audited seed artifact.
3. Runtime baseline is no-libc and raw OS ABI/syscall facing.
4. Linux x86_64 ELF comes before Windows x64 PE in the v0 target order.

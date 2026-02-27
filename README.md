# Fin

Fin is a full-independent native programming language project with the `.fn` extension.

## Project Goals

- Zero-cost abstractions.
- Simple, low-typing syntax.
- Low cognitive load and ergonomic defaults.
- Native performance and deterministic builds.
- No external compiler/assembler/linker in the normal build pipeline.

## Current Status

This repository implements the foundation phase:

- Governance and standards are in place.
- FIP lifecycle and proposal corpus (`FIP-0001` to `FIP-0020`) are in place.
- Bootstrap trust model is defined (`seed/`).
- CI policy gates for independent toolchain and FIP linkage are defined.
- Stage0 direct ELF emitter starter is implemented (`compiler/finc/stage0/emit_elf_exit0.ps1`).
- Bootstrap CLI shim with `doctor` is available (`./fin.ps1 doctor`).
- Compiler/linker/object-format/assembler tracks are scaffolded.

## Repository Layout

- `fips/`: language and tooling proposals.
- `docs/`: architecture, bootstrap, quality, and policy docs.
- `compiler/`: `finc`, `finld`, `finobj`, `finas` tracks.
- `runtime/`: OS ABI and syscall-facing runtime tracks.
- `seed/`: audited genesis seed metadata.
- `ci/`: policy checks used by CI.
- `.github/`: workflow and contribution templates.

## Non-Negotiable Constraints

1. External toolchain use is forbidden in normal builds.
2. Bootstrap trust anchor is an audited seed binary.
3. Runtime baseline is no-libc and raw OS ABI/syscalls.
4. v0 target order is Linux x86_64 first, then Windows x64.

## CLI Contract (Planned)

The unified `fin` CLI contract is tracked in `FIP-0015`:

- `fin init`
- `fin build`
- `fin run`
- `fin test`
- `fin fmt`
- `fin doc`
- `fin pkg add`
- `fin pkg publish`
- `fin doctor`

## Governance

- Proposal address format: `fin://fip/FIP-####`.
- Proposal lifecycle: `Draft`, `Review`, `Accepted`, `Scheduled`, `InProgress`, `Implemented`, `Released`, `Deferred`, `Rejected`.
- Feature PRs must link an `Accepted` or `Scheduled` FIP.

See [GOVERNANCE.md](GOVERNANCE.md), [SPEC.md](SPEC.md), and [fips/README.md](fips/README.md).

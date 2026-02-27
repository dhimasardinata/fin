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
- Reproducibility and toolchain-policy self-checks are integrated into stage0 test suite.
- Stage0 direct ELF emitters are implemented (`emit_elf_exit0.ps1`, `emit_elf_write_exit.ps1`).
- Stage0 direct PE emitter starter is implemented (`emit_pe_exit0.ps1`).
- Stage0 minimal parser/build path is implemented for `.fn` subset.
- Bootstrap CLI shim covers stage0 workflows (`init`, `doctor`, `build`, `run`, `fmt`, `doc`, `pkg add`, `pkg publish`, `test`).
- Stage0 bootstrap closure proxy witness is implemented with baseline verification (`tests/bootstrap/verify_stage0_closure.ps1`, `seed/stage0-closure-baseline.txt`).
- Stage0 finobj/finld starter flow is implemented for single-unit object-to-ELF path.
- Stage0 build/run supports selectable pipeline (`direct` or `finobj`) for Linux ELF outputs.
- Compiler/linker/object-format/assembler tracks are scaffolded.

## Stage0 Quick Start

1. Initialize project scaffold: `./fin.ps1 init --name demo --dir artifacts/tmp/demo`
2. Run policy checks: `./fin.ps1 doctor`
3. Build default source: `./fin.ps1 build`
4. Build and run default source: `./fin.ps1 run`
5. Build Windows PE target from `.fn`: `./fin.ps1 build --target x86_64-windows-pe --out artifacts/main.exe`
6. Build and run Windows PE target (runtime auto-skips on non-Windows): `./fin.ps1 run --target x86_64-windows-pe --out artifacts/main.exe`
7. Build through finobj+finld stage0 path: `./fin.ps1 build --pipeline finobj`
8. Build and run a specific file: `./fin.ps1 run --src tests/conformance/fixtures/main_exit7.fn --out artifacts/fin-build-exit7 --expect-exit 7`
9. Format source subset: `./fin.ps1 fmt --src src/main.fn`
10. Generate source docs: `./fin.ps1 doc --src src/main.fn --out docs/main.md`
11. Add dependency and sync lockfile: `./fin.ps1 pkg add serde --version 1.2.3`
12. Create publish artifact: `./fin.ps1 pkg publish --out-dir artifacts/publish`
13. Run Linux syscall smoke (`write + exit`): `./tests/integration/verify_linux_write_exit.ps1`
14. Generate closure witness: `./tests/bootstrap/verify_stage0_closure.ps1`
15. Verify PE structure sample: `./tests/integration/verify_windows_pe_exit.ps1`
16. Verify finobj link sample: `./tests/integration/verify_finobj_link.ps1`
17. Run full stage0 suite: `./fin.ps1 test`

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

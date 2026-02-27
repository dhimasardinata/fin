# FIP-0015: Unified fin CLI Contract

- id: FIP-0015
- address: fin://fip/FIP-0015
- status: Implemented
- authors: @fin-maintainers
- created: 2026-02-27
- requires: ["FIP-0002"]
- target_release: M3
- discussion: TBD
- implementation:
  - cmd/fin/fin.ps1
  - fin.ps1
  - cmd/fin/README.md
  - compiler/finc/stage0/build_stage0.ps1
  - compiler/finc/stage0/format_main_exit.ps1
  - compiler/finc/stage0/doc_main_exit.ps1
  - compiler/finc/stage0/pkg_add.ps1
  - compiler/finc/stage0/pkg_publish.ps1
  - tests/integration/run_linux_elf.ps1
  - tests/run_stage0_suite.ps1
  - tests/integration/verify_init.ps1
  - tests/integration/verify_fmt.ps1
  - tests/integration/verify_doc.ps1
  - tests/integration/verify_pkg.ps1
  - tests/integration/verify_pkg_publish.ps1
- acceptance:
  - CLI behavior tests pass for all mandatory commands.

## Summary

Defines command-line UX and command semantics.

## Motivation

This proposal is part of the Fin independent-toolchain baseline and is required to keep the language and tooling direction explicit and auditable.

## Design

Bootstrap implementation is available as a PowerShell shim until the native `fin` binary exists.

Current commands:

1. `init`: scaffolds `fin.toml`, `fin.lock`, and `src/main.fn`.
2. `doctor`: executes policy and seed checks.
3. `emit-elf-exit0`: runs the FIP-0010 stage0 emitter and verifier.
4. `build`: parses stage0 `.fn` subset and emits a verified ELF artifact.
5. `run`: builds (optional) and executes Linux ELF artifact with expected exit-code assertion.
6. `fmt`: formats stage0 `.fn` subset into canonical style.
7. `doc`: generates stage0 documentation from `.fn` subset.
8. `pkg add`: inserts/updates dependency entries in `fin.toml` and rewrites `fin.lock`.
9. `pkg publish`: emits deterministic stage0 package artifact (`.fnpkg`).
10. `test`: executes aggregated stage0 test suite.

This preserves forward compatibility with the planned unified CLI contract while enabling immediate policy enforcement.

## Alternatives

Alternatives are considered in milestone planning and linked PR discussions. Rejected alternatives must be listed here when status moves beyond Review.

## Risks

Implementation complexity and schedule risk are tracked in milestone updates and test gates.

## Compatibility

Compatibility impact must be documented before Implemented status.

## Test Plan

Current checks:

1. `./fin.ps1 init --dir <tmp> --name <name>` creates expected scaffold files.
2. `./fin.ps1 doctor` succeeds on compliant repos.
3. `./fin.ps1 emit-elf-exit0` produces and verifies a valid ELF sample.
4. `./fin.ps1 build --src tests/conformance/fixtures/main_exit7.fn --out artifacts/fin-build-exit7` succeeds.
5. `./fin.ps1 run` executes default stage0 program.
6. `./fin.ps1 run --no-build --out artifacts/fin-build-exit7 --expect-exit 7` executes fixture artifact.
7. `./fin.ps1 fmt --src <file>` rewrites stage0 source to canonical form.
8. `./fin.ps1 fmt --src <file> --check` fails on unformatted source and passes on formatted source.
9. `./fin.ps1 doc --src <file> --out <file>` generates doc output with expected summary and exit code.
10. `./fin.ps1 doc --src <file> --stdout` prints generated document.
11. `./fin.ps1 pkg add <name[@version]>` updates manifest dependencies and rewrites `fin.lock` deterministically.
12. `./fin.ps1 pkg publish --manifest fin.toml --src src --out-dir artifacts/publish` emits deterministic stage0 package artifact.
13. `./fin.ps1 test` executes stage0 suite end-to-end.

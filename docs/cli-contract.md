# fin CLI Contract (Draft)

The `fin` command is the single entry point for compiler and package workflows.

## Bootstrap Shim

Until native `fin` is available, a compatibility shim is provided:

- `./fin.ps1 init [--name <project>] [--dir <path>] [--force]`
- `./fin.ps1 doctor`
- `./fin.ps1 emit-elf-exit0 [output-path]`
- `./fin.ps1 build [--src <file>] [--out <file>] [--pipeline <direct|finobj>] [--no-verify]`
- `./fin.ps1 run [--src <file>] [--out <file>] [--pipeline <direct|finobj>] [--no-build] [--expect-exit <0..255>] [--no-verify]`
- `./fin.ps1 fmt [--src <file>] [--check | --stdout]`
- `./fin.ps1 doc [--src <file>] [--out <file> | --stdout]`
- `./fin.ps1 pkg add <name[@version]> [--version <ver>] [--manifest <path>]`
- `./fin.ps1 pkg publish [--manifest <path>] [--src <dir>] [--out-dir <path>] [--dry-run]`
- `./fin.ps1 test [--quick] [--no-doctor] [--no-run]`

## Commands

- `fin init`: create a new package layout.
- `fin build`: compile current package.
- `fin run`: build and execute current package.
- `fin test`: run package tests.
- `fin fmt`: format `.fn` files.
- `fin doc`: generate API and language docs.
- `fin pkg add <name>`: add dependency and update `fin.lock`.
- `fin pkg publish`: publish package.
- `fin doctor`: validate environment and policy constraints.

This contract is normative once `FIP-0015` reaches `Accepted`.

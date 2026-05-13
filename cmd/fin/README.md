# fin CLI Track

Command contract is defined in `FIP-0015`.

Current bootstrap shim:

- `./fin.ps1 init [--name <project>] [--dir <path>] [--force]`
- `./fin.ps1 doctor`
- `./fin.ps1 emit-elf-exit0 [output-path]`
- `./fin.ps1 build [--src <file>] [--out <file>] [--manifest <path>] [--target <x86_64-linux-elf|x86_64-windows-pe>] [--pipeline <direct|finobj>] [--no-verify]`
- `./fin.ps1 run [--src <file>] [--out <file>] [--manifest <path>] [--target <x86_64-linux-elf|x86_64-windows-pe>] [--pipeline <direct|finobj>] [--no-build] [--expect-exit <0..255>] [--no-verify]`
- `./fin.ps1 fmt [--src <file>] [--check | --stdout]`
- `./fin.ps1 doc [--src <file>] [--out <file> | --stdout]`
- `./fin.ps1 pkg add <name[@version]> [--version <ver>] [--manifest <path>]`
- `./fin.ps1 pkg publish [--manifest <path>] [--src <dir>] [--out-dir <path>] [--dry-run]`
- `./fin.ps1 test [--quick] [--no-doctor] [--no-run]`

`test --quick` keeps shared gates and uses a smoke fixture matrix. Plain
`test` runs the exhaustive fixture build/run matrix.

Unified commands tracked in `FIP-0015`:

- `fin init`
- `fin build`
- `fin run`
- `fin test`
- `fin fmt`
- `fin doc`
- `fin pkg add`
- `fin pkg publish`
- `fin doctor`

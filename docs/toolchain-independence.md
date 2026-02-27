# Toolchain Independence Standard

Normal build and test jobs must not call:

- `clang`, `clang++`, `gcc`, `g++`, `cc`
- `ld`, `ld.lld`, `lld-link`, `link.exe`
- `as`, `nasm`, `yasm`, `ml`, `ml64`

The prohibition is enforced by `ci/forbid_external_toolchain.ps1`.

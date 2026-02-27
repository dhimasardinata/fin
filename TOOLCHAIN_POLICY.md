# Build and Toolchain Policy

Normal build and test flows must not invoke external compilers/assemblers/linkers.

Disallowed command families in normal pipelines include:

- `clang`, `clang++`, `gcc`, `g++`, `cc`
- `ld`, `ld.lld`, `lld-link`, `link.exe`
- `as`, `nasm`, `yasm`, `ml64`, `ml`

Bootstrap exceptions must be explicitly documented by a ratified FIP and be outside normal release gates.

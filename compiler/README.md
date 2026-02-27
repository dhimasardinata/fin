# Compiler Workspace

This directory contains language toolchain tracks:

- `finc/`: compiler frontend and executable emitter.
- `finobj/`: relocatable object format.
- `finld/`: linker implementation.
- `finas/`: optional assembler track.

Normal build path must stay independent from external toolchains.

Stage0 now includes starter finobj/finld scripts for deterministic single-unit object/link flows.

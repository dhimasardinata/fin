# Architecture Overview

Fin architecture is intentionally staged to support full independence while keeping implementation tractable.

## Components

- `fin-seed`: audited genesis compiler artifact.
- `finc`: language frontend and executable emitter.
- `finobj`: internal object representation (post direct-emitter stage).
- `finld`: linker for multi-unit and archive workflows.
- `finas`: optional assembler if text assembly becomes a maintained interface.

## Pipeline (planned)

1. Lexing and parsing into AST.
2. Type analysis and inference.
3. Ownership and borrow checking.
4. MIR/low-level IR.
5. Direct machine code emission.
6. Final executable image generation (ELF first, PE second).

## Independence Rule

Normal build paths do not invoke external compiler/assembler/linker tools.

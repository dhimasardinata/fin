# Architecture Overview

Fin architecture is intentionally staged to support full independence while keeping implementation tractable.

## Components

- `fin-seed`: audited genesis compiler artifact.
- `finc`: language frontend, stage0 evaluator, and executable emitter.
- `finobj`: internal object representation used by the stage0 object pipeline.
- `finld`: linker for stage0 finobj inputs and later multi-unit/archive workflows.
- `finas`: optional assembler if text assembly becomes a maintained interface.

## Current Stage0 Pipeline

The current bootstrap pipeline is intentionally narrow and deterministic:

1. Parse one `.fn` source file as the Stage0 compilation unit.
2. Resolve the entrypoint and helper functions into a concrete `u8` exit code.
3. Emit a native image directly for Linux ELF or Windows PE.
4. Optionally route through `finobj` + `finld` before native image emission.
5. Verify emitted structures and runtime exit behavior through the Stage0 test suite.

## Future Compiler Pipeline

1. Lexing and parsing into AST.
2. Type analysis and inference.
3. Ownership and borrow checking.
4. MIR/low-level IR.
5. Direct machine code emission.
6. Final executable image generation (ELF first, PE second).

## Independence Rule

Normal build paths do not invoke external compiler/assembler/linker tools.

# Windows x64 Runtime Surface

Stage0 contract for direct PE emission:

## Entry Contract

1. PE entrypoint is native x64 machine code in `.text`.
2. Stage0 minimal path sets process exit code by returning value in `eax` from entrypoint.
3. No import table or external runtime dependencies are used for the stage0 exit-only sample.

## Current Usage

- `emit_pe_exit0.ps1`: emits PE32+ image with payload:
  - `mov eax, <u8>`
  - `ret`

This is a deterministic bootstrap stepping stone before richer Windows ABI/API integration.

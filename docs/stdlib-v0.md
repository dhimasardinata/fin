# Lean Stdlib v0 Contract

This document records the Review-stage contract for `FIP-0017`.

## Constraints

The v0 standard library must stay lean and no-libc:

- no dependency on libc, CRT startup, shell commands, or external runtime libraries in normal build output;
- OS interaction goes through Fin-owned ABI/runtime surfaces;
- APIs must map to deterministic stage0 or later native codegen paths;
- unsupported APIs must fail at compile time rather than silently calling host tools.

## Initial API Lanes

The first stdlib surface is limited to runtime primitives that are already represented by Stage0 ABI evidence:

| API lane | Contract | Current ABI evidence |
|---|---|---|
| `std.proc.exit(code: u8)` | terminate process with an 8-bit code | Linux `sys_exit`; Windows PE entry return in `eax` |
| `std.io.write_stdout(bytes)` | write bytes to standard output, returning a status/result in later language slices | Linux `sys_write` smoke path |

The current Stage0 language does not yet expose these names as importable modules. Until module/import support lands, the direct emitters are the executable ABI witnesses for these stdlib lanes:

- `compiler/finc/stage0/emit_elf_exit0.ps1`
- `compiler/finc/stage0/emit_elf_write_exit.ps1`
- `compiler/finc/stage0/emit_pe_exit0.ps1`

## Runtime Mapping

Linux x86_64:

- `std.proc.exit` maps to syscall `60` (`sys_exit`) with code in `rdi`.
- `std.io.write_stdout` maps to syscall `1` (`sys_write`) with `fd=1`, buffer pointer in `rsi`, and length in `rdx`.

Windows x64 Stage0:

- `std.proc.exit` maps to returning the code in `eax` from the PE entrypoint.
- `std.io.write_stdout` remains future work because Stage0 PE currently has no import table and no external runtime dependency.

## Completion Requirements

Before `FIP-0017` can move to `Implemented`:

1. Importable stdlib module names must be parsed and resolved by the compiler.
2. `std.proc.exit` and `std.io.write_stdout` must have source-level conformance fixtures.
3. Linux and Windows runtime behavior must be covered without libc or external runtime dependencies.
4. Reproducibility checks must include any stdlib-generated output paths.

# finld

`finld` is the Fin-native linker track.

## Scope

- Symbol resolution.
- Relocation processing.
- Minimal static linking first.

This component is deferred until direct executable emitters are stable.

## Stage0 Starter

Stage0 includes minimal multi-object linking flow:

- `stage0/link_finobj_to_elf.ps1`: reads stage0 `.finobj` inputs and emits final native image for target (`x86_64-linux-elf` or `x86_64-windows-pe`) using direct emitter paths.
  - requires exactly one `entry_symbol=main` object
  - allows additional `entry_symbol=unit` objects
  - rejects duplicate object paths and duplicate object identities
  - validates symbol graph metadata (`provides`/`requires`/`symbol_values`) for duplicate providers and unresolved symbols
  - validates relocation metadata (`relocs`) for resolved relocation targets (with stage0 relocation kinds from finobj)
  - materializes entry-object relocations into emitted stage0 code bytes using resolved provider symbol values (Linux supports `abs32`/`rel32`; Windows stage0 supports `abs32` only)
  - rejects non-entry relocation materialization, relocation offsets outside stage0 target code bounds, relocation sites that are not valid stage0 immediate patch offsets for the selected target, and relocation kinds unsupported for the selected target
  - emits symbol-resolution witness hash for deterministic auditability
  - emits relocation-resolution witness hash for deterministic auditability (including relocation kind + resolved value)
  - supports `-AsRecord` structured diagnostics output (including object-set, symbol-resolution, and relocation-resolution witness hashes)
  - reports `LinkedRelocationsAppliedCount` in `-AsRecord` and stdout diagnostics
  - requires the entry object to provide `main` symbol
  - canonicalizes object metadata order for deterministic order-independent linking
- `fin build --pipeline finobj`: routes stage0 compile flow through `finobj` writer + `finld` link path.

This is a minimal linker checkpoint before full symbol/relocation implementation.

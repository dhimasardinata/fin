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
- `fin build --pipeline finobj`: routes stage0 compile flow through `finobj` writer + `finld` link path.

This is a minimal linker checkpoint before full symbol/relocation implementation.

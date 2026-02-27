# finobj

`finobj` defines Fin relocatable object representation.

## Stage0 Starter

Stage0 provides a deterministic object container for minimal multi-object checkpoint programs:

- `stage0/write_finobj_exit.ps1`: writes `.finobj` from `.fn` source.
- `stage0/read_finobj_exit.ps1`: reads `.finobj` metadata and exit code with strict schema validation.
- `fin build --pipeline finobj`: uses this format as the stage0 build handoff into `finld`.

Stage0 symbol metadata:

- `provides`: symbols defined by the object (defaults to `main` for `entry_symbol=main`).
- `requires`: symbols required from other objects (defaults to empty).
- `relocs`: relocation references (`<symbol>@<offset>`) validated against `requires` in stage0.

Entry symbols currently supported:

- `main`: link entry object.
- `unit`: non-entry object for stage0 linker multi-object checkpoint.

This starter is intentionally minimal and serves as a stepping stone toward full relocatable multi-unit format.

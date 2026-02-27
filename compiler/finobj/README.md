# finobj

`finobj` defines Fin relocatable object representation.

## Stage0 Starter

Stage0 provides a deterministic object container for single-unit `main` exit programs:

- `stage0/write_finobj_exit.ps1`: writes `.finobj` from `.fn` source.
- `stage0/read_finobj_exit.ps1`: reads `.finobj` metadata and exit code.
- `fin build --pipeline finobj`: uses this format as the stage0 build handoff into `finld`.

This starter is intentionally minimal and serves as a stepping stone toward full relocatable multi-unit format.

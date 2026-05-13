# Standard Library (Lean v0)

FIP-0017 tracks the lean standard library surface. Stage0 publishes the module
contract first; executable stdlib implementations land behind follow-on gates.

## Stage0 API Plan

Planned minimal modules:

- `core`: primitive value helpers and compiler-recognized language prelude.
- `result`: `Result` helpers once non-bootstrap generic result support lands.
- `sys`: portable wrappers over Fin runtime syscall/ABI shims.
- `io`: byte-oriented input/output built on `sys`, not host C library calls.
- `time`: monotonic and wall-clock contracts backed by runtime shims.
- `alloc`: allocator contracts after no-libc heap ownership is specified.
- `thread`: thread lifecycle contracts after target runtimes expose them.
- `channel`: synchronization/message-passing contracts built on `thread`.

## No-libc Contract

No libc assumptions are allowed in stable runtime contracts.
Stdlib APIs must route operating-system behavior through Fin runtime shims and
the target ABI contracts tracked by FIP-0009 and FIP-0012.

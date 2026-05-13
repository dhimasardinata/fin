# Stage0 Source Module Layout

This example demonstrates the current `FIP-0004` Stage0 source layout: one `.fn` file with `main` plus typed helper functions.

```powershell
./fin.ps1 run --src examples/stage0/source_module_layout/main.fn --expect-exit 43
./fin.ps1 run --src examples/stage0/source_module_layout/main.fn --pipeline finobj --expect-exit 43
```

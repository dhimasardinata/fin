# Runtime

Runtime baseline is no-libc and OS ABI/syscall-facing.

- `linux_x86_64/`: Linux ABI and syscall interfaces.
- `windows_x64/`: Windows ABI and system call interfaces.

Stage0 currently has direct image emission checks for both Linux ELF and Windows PE minimal exit paths.

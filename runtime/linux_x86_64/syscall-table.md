# Linux x86_64 Runtime Surface

Stage0 contract for direct syscall emission (no libc):

## Register Convention

- syscall number: `rax`
- arg0: `rdi`
- arg1: `rsi`
- arg2: `rdx`
- return value: `rax`

## Stage0 Syscall Table

| Name | Number | Purpose | Inputs |
|---|---:|---|---|
| `sys_write` | `1` | write bytes to fd | `rdi=fd`, `rsi=buf`, `rdx=len` |
| `sys_exit` | `60` | terminate process | `rdi=exit_code` |

## Current Usage

- `emit_elf_exit0.ps1`: emits `sys_exit` payload.
- `emit_elf_write_exit.ps1`: emits `sys_write` then `sys_exit` payload.

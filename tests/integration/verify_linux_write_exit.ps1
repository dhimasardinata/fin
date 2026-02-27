Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$emit = Join-Path $repoRoot "compiler/finc/stage0/emit_elf_write_exit.ps1"
$verify = Join-Path $repoRoot "tests/bootstrap/verify_elf_write_exit.ps1"
$run = Join-Path $repoRoot "tests/integration/run_linux_elf.ps1"
$out = Join-Path $repoRoot "artifacts/fin-elf-write-exit"

$message = "fin stage0 syscall smoke"
[int]$exitCode = 23

& $emit -OutFile $out -Message $message -ExitCode $exitCode
& $verify -Path $out -ExpectedMessage $message -ExpectedExitCode $exitCode
& $run -Path $out -ExpectedExitCode $exitCode -ExpectedStdout $message

Write-Host "linux write+exit integration check passed."

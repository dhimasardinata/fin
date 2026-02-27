param(
    [string]$Path = "artifacts/fin-pe-exit0.exe",
    [ValidateRange(0, 255)]
    [int]$ExpectedExitCode = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$emit = Join-Path $repoRoot "compiler/finc/stage0/emit_pe_exit0.ps1"
$verify = Join-Path $repoRoot "tests/bootstrap/verify_pe_exit0.ps1"
$run = Join-Path $repoRoot "tests/integration/run_windows_pe.ps1"

$target = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path $repoRoot $Path }

& $emit -OutFile $target -ExitCode $ExpectedExitCode
& $verify -Path $target -ExpectedExitCode $ExpectedExitCode
& $run -Path $target -ExpectedExitCode $ExpectedExitCode

Write-Host "windows pe integration check passed."

param(
    [Parameter(Position = 0)]
    [string]$Command = "",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")

function Invoke-Doctor {
    Write-Host "fin doctor: checking repository policy and bootstrap metadata"
    & (Join-Path $repoRoot "ci/verify_manifest.ps1")
    & (Join-Path $repoRoot "ci/verify_seed_hash.ps1")
    & (Join-Path $repoRoot "ci/forbid_external_toolchain.ps1")
    Write-Host "fin doctor: all checks passed"
}

function Invoke-EmitElfExit0 {
    $outFile = if ($Args.Count -gt 0 -and $Args[0]) { $Args[0] } else { "artifacts/fin-elf-exit0" }
    & (Join-Path $repoRoot "compiler/finc/stage0/emit_elf_exit0.ps1") -OutFile $outFile
    & (Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1") -Path $outFile
}

function Show-Usage {
    @"
fin bootstrap CLI (PowerShell shim)

Usage:
  ./cmd/fin/fin.ps1 doctor
  ./cmd/fin/fin.ps1 emit-elf-exit0 [output-path]

Planned unified commands (tracked in FIP-0015):
  fin init | build | run | test | fmt | doc | pkg add | pkg publish | doctor
"@ | Write-Host
}

switch ($Command) {
    "doctor" { Invoke-Doctor; break }
    "emit-elf-exit0" { Invoke-EmitElfExit0; break }
    "" { Show-Usage; break }
    default {
        Write-Error "Unknown command: $Command"
        Show-Usage
        exit 1
    }
}

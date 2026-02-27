param(
    [Parameter(Position = 0)]
    [string]$Command = "",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
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
    $outFile = if ($CommandArgs.Count -gt 0 -and $CommandArgs[0]) { $CommandArgs[0] } else { "artifacts/fin-elf-exit0" }
    & (Join-Path $repoRoot "compiler/finc/stage0/emit_elf_exit0.ps1") -OutFile $outFile
    & (Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1") -Path $outFile
}

function Invoke-Build {
    $source = "src/main.fn"
    $outFile = "artifacts/main"
    $verify = $true

    for ($i = 0; $i -lt $CommandArgs.Count; $i++) {
        if ([string]::IsNullOrWhiteSpace($CommandArgs[$i])) {
            continue
        }
        switch ($CommandArgs[$i]) {
            "--src" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--src requires a value" }
                $source = $CommandArgs[++$i]
            }
            "--out" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--out requires a value" }
                $outFile = $CommandArgs[++$i]
            }
            "--no-verify" {
                $verify = $false
            }
            default {
                throw "Unknown build argument: $($CommandArgs[$i])"
            }
        }
    }

    if ($verify) {
        & (Join-Path $repoRoot "compiler/finc/stage0/build_stage0.ps1") -Source $source -OutFile $outFile -Verify
    }
    else {
        & (Join-Path $repoRoot "compiler/finc/stage0/build_stage0.ps1") -Source $source -OutFile $outFile
    }
}

function Show-Usage {
    @"
fin bootstrap CLI (PowerShell shim)

Usage:
  ./cmd/fin/fin.ps1 doctor
  ./cmd/fin/fin.ps1 emit-elf-exit0 [output-path]
  ./cmd/fin/fin.ps1 build [--src <file>] [--out <file>] [--no-verify]

Planned unified commands (tracked in FIP-0015):
  fin init | build | run | test | fmt | doc | pkg add | pkg publish | doctor
"@ | Write-Host
}

switch ($Command) {
    "doctor" { Invoke-Doctor; break }
    "emit-elf-exit0" { Invoke-EmitElfExit0; break }
    "build" { Invoke-Build; break }
    "" { Show-Usage; break }
    default {
        Write-Error "Unknown command: $Command"
        Show-Usage
        exit 1
    }
}

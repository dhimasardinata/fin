param(
    [switch]$Quick,
    [switch]$SkipDoctor,
    [switch]$SkipRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$emit = Join-Path $repoRoot "compiler/finc/stage0/emit_elf_exit0.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$verifyGrammar = Join-Path $repoRoot "tests/conformance/verify_stage0_grammar.ps1"

Write-Host "fin test: stage0 suite starting"

if (-not $SkipDoctor) {
    & $fin doctor
}

& $emit -OutFile (Join-Path $repoRoot "artifacts/fin-elf-exit0") -ExitCode 0
& $verifyElf -Path (Join-Path $repoRoot "artifacts/fin-elf-exit0") -ExpectedExitCode 0

& $verifyGrammar

& $fin build --src tests/conformance/fixtures/main_exit0.fn --out artifacts/test-exit0
& $fin build --src tests/conformance/fixtures/main_exit7.fn --out artifacts/test-exit7

if (-not $SkipRun) {
    & $fin run --no-build --out artifacts/test-exit0 --expect-exit 0
    if (-not $Quick) {
        & $fin run --no-build --out artifacts/test-exit7 --expect-exit 7
    }
}

Write-Host "fin test: stage0 suite passed"

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$parser = Join-Path $repoRoot "compiler/finc/stage0/parse_main_exit.ps1"

$ok0 = & $parser -SourcePath (Join-Path $repoRoot "tests/conformance/fixtures/main_exit0.fn")
if ([int]$ok0 -ne 0) {
    Write-Error "Expected main_exit0.fn to parse with exit code 0."
    exit 1
}

$ok7 = & $parser -SourcePath (Join-Path $repoRoot "tests/conformance/fixtures/main_exit7.fn")
if ([int]$ok7 -ne 7) {
    Write-Error "Expected main_exit7.fn to parse with exit code 7."
    exit 1
}

$invalid = Join-Path $repoRoot "tests/conformance/fixtures/invalid_missing_main.fn"
$failed = $false
try {
    & $parser -SourcePath $invalid | Out-Null
}
catch {
    $failed = $true
}

if (-not $failed) {
    Write-Error "Expected invalid fixture to fail parsing."
    exit 1
}

Write-Host "Stage0 grammar conformance check passed."

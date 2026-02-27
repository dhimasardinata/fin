Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$writer = Join-Path $repoRoot "compiler/finobj/stage0/write_finobj_exit.ps1"
$reader = Join-Path $repoRoot "compiler/finobj/stage0/read_finobj_exit.ps1"
$tmpDir = Join-Path $repoRoot "artifacts/tmp/finobj-roundtrip"

if (Test-Path $tmpDir) {
    Remove-Item -Recurse -Force $tmpDir
}
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

$source = Join-Path $repoRoot "tests/conformance/fixtures/main_exit7.fn"
$objA = Join-Path $tmpDir "a.finobj"
$objB = Join-Path $tmpDir "b.finobj"

& $writer -SourcePath $source -OutFile $objA
& $writer -SourcePath $source -OutFile $objB

$hashA = (Get-FileHash -Path $objA -Algorithm SHA256).Hash
$hashB = (Get-FileHash -Path $objB -Algorithm SHA256).Hash
if ($hashA -ne $hashB) {
    Write-Error "Expected deterministic finobj writer output hash."
    exit 1
}

$exitCode = [int](& $reader -ObjectPath $objA)
if ($exitCode -ne 7) {
    Write-Error ("Expected finobj reader exit code 7, got {0}" -f $exitCode)
    exit 1
}

$badObj = Join-Path $tmpDir "invalid.finobj"
Set-Content -Path $badObj -Value "finobj_format=bad`nfinobj_version=1`nexit_code=0`n"
$failed = $false
try {
    & $reader -ObjectPath $badObj | Out-Null
}
catch {
    $failed = $true
}
if (-not $failed) {
    Write-Error "Expected finobj reader to fail for invalid object."
    exit 1
}

Write-Host "finobj roundtrip conformance check passed."

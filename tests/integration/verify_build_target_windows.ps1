Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$verifyPe = Join-Path $repoRoot "tests/bootstrap/verify_pe_exit0.ps1"
$runPe = Join-Path $repoRoot "tests/integration/run_windows_pe.ps1"
$tmpDir = Join-Path $repoRoot "artifacts/tmp/build-target-windows-smoke"

if (Test-Path $tmpDir) {
    Remove-Item -Recurse -Force $tmpDir
}
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

function Assert-Fails {
    param(
        [scriptblock]$Action,
        [string]$Label
    )

    $failed = $false
    try {
        & $Action
    }
    catch {
        $failed = $true
    }

    if (-not $failed) {
        Write-Error ("Expected failure: {0}" -f $Label)
        exit 1
    }
}

$source = "tests/conformance/fixtures/main_exit7.fn"
$buildOut = Join-Path $tmpDir "main-build.exe"
$runOut = Join-Path $tmpDir "main-run.exe"
$badOut = Join-Path $tmpDir "main-bad.exe"

& $fin build --src $source --out $buildOut --target x86_64-windows-pe
& $verifyPe -Path $buildOut -ExpectedExitCode 7
& $runPe -Path $buildOut -ExpectedExitCode 7

& $fin run --src $source --out $runOut --target x86_64-windows-pe --expect-exit 7
& $verifyPe -Path $runOut -ExpectedExitCode 7

Assert-Fails -Action {
    & $fin build --src $source --out $badOut --target x86_64-windows-pe --pipeline finobj | Out-Null
} -Label "windows target with finobj pipeline"

Write-Host "build target windows integration check passed."

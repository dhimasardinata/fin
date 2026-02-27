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

$source = "tests/conformance/fixtures/main_exit7.fn"
$buildOut = Join-Path $tmpDir "main-build.exe"
$buildFinobjOut = Join-Path $tmpDir "main-build-finobj.exe"
$runOut = Join-Path $tmpDir "main-run.exe"
$runFinobjOut = Join-Path $tmpDir "main-run-finobj.exe"

& $fin build --src $source --out $buildOut --target x86_64-windows-pe
& $fin build --src $source --out $buildFinobjOut --target x86_64-windows-pe --pipeline finobj
& $verifyPe -Path $buildOut -ExpectedExitCode 7
& $verifyPe -Path $buildFinobjOut -ExpectedExitCode 7
& $runPe -Path $buildOut -ExpectedExitCode 7
& $runPe -Path $buildFinobjOut -ExpectedExitCode 7

& $fin run --src $source --out $runOut --target x86_64-windows-pe --expect-exit 7
& $fin run --src $source --out $runFinobjOut --target x86_64-windows-pe --pipeline finobj --expect-exit 7
& $verifyPe -Path $runOut -ExpectedExitCode 7
& $verifyPe -Path $runFinobjOut -ExpectedExitCode 7

$directHash = (Get-FileHash -Path $buildOut -Algorithm SHA256).Hash.ToLowerInvariant()
$finobjHash = (Get-FileHash -Path $buildFinobjOut -Algorithm SHA256).Hash.ToLowerInvariant()
if ($directHash -ne $finobjHash) {
    Write-Error ("windows pipeline mismatch: direct={0} finobj={1}" -f $directHash, $finobjHash)
    exit 1
}

Write-Host "build target windows integration check passed."

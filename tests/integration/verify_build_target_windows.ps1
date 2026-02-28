Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$verifyPe = Join-Path $repoRoot "tests/bootstrap/verify_pe_exit0.ps1"
$runPe = Join-Path $repoRoot "tests/integration/run_windows_pe.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
$finobjHelpers = Join-Path $repoRoot "tests/common/finobj_output_helpers.ps1"
. $tmpWorkspace
. $finobjHelpers
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "build-target-windows-smoke-"
$tmpDir = $tmpState.TmpDir

$source = "tests/conformance/fixtures/main_exit7.fn"
$buildOut = Join-Path $tmpDir "main-build.exe"
$buildFinobjOut = Join-Path $tmpDir "main-build-finobj.exe"
$runOut = Join-Path $tmpDir "main-run.exe"
$runFinobjOut = Join-Path $tmpDir "main-run-finobj.exe"

& $fin build --src $source --out $buildOut --target x86_64-windows-pe
$buildFinobjResult = Invoke-FinCommandCaptureFinobjOutput -Action {
    & $fin build --src $source --out $buildFinobjOut --target x86_64-windows-pe --pipeline finobj
} -Label "fin build --target x86_64-windows-pe --pipeline finobj"
$buildFinobjObj = $buildFinobjResult.FinobjPath
& $verifyPe -Path $buildOut -ExpectedExitCode 7
& $verifyPe -Path $buildFinobjOut -ExpectedExitCode 7
& $runPe -Path $buildOut -ExpectedExitCode 7
& $runPe -Path $buildFinobjOut -ExpectedExitCode 7

& $fin run --src $source --out $runOut --target x86_64-windows-pe --expect-exit 7
$runFinobjResult = Invoke-FinCommandCaptureFinobjOutput -Action {
    & $fin run --src $source --out $runFinobjOut --target x86_64-windows-pe --pipeline finobj --expect-exit 7
} -Label "fin run --target x86_64-windows-pe --pipeline finobj"
$runFinobjObj = $runFinobjResult.FinobjPath
& $verifyPe -Path $runOut -ExpectedExitCode 7
& $verifyPe -Path $runFinobjOut -ExpectedExitCode 7

$null = Assert-FileSha256Equal -LeftPath $buildOut -RightPath $buildFinobjOut -Label "windows pipeline"

Assert-FinobjTempArtifactCleaned -Path $buildFinobjObj -Label "build"
Assert-FinobjTempArtifactCleaned -Path $runFinobjObj -Label "run"

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "build target windows integration check passed."

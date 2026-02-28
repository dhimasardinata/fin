Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$runLinux = Join-Path $repoRoot "tests/integration/run_linux_elf.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
$finobjHelpers = Join-Path $repoRoot "tests/common/finobj_output_helpers.ps1"
. $tmpWorkspace
. $finobjHelpers
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "build-pipeline-smoke-"
$tmpDir = $tmpState.TmpDir

$source = "tests/conformance/fixtures/main_exit7.fn"
$directOut = Join-Path $tmpDir "main-direct"
$finobjOut = Join-Path $tmpDir "main-finobj"
$runOut = Join-Path $tmpDir "main-run-finobj"

& $fin build --src $source --out $directOut --pipeline direct
$buildFinobjResult = Invoke-FinCommandCaptureFinobjOutput -Action {
    & $fin build --src $source --out $finobjOut --pipeline finobj
} -Label "fin build --pipeline finobj"
$buildFinobjObj = $buildFinobjResult.FinobjPath

& $verifyElf -Path $directOut -ExpectedExitCode 7
& $verifyElf -Path $finobjOut -ExpectedExitCode 7
& $runLinux -Path $directOut -ExpectedExitCode 7
& $runLinux -Path $finobjOut -ExpectedExitCode 7

$directHash = (Get-FileHash -Path $directOut -Algorithm SHA256).Hash.ToLowerInvariant()
$finobjHash = (Get-FileHash -Path $finobjOut -Algorithm SHA256).Hash.ToLowerInvariant()
if ($directHash -ne $finobjHash) {
    Write-Error ("build pipeline mismatch: direct={0} finobj={1}" -f $directHash, $finobjHash)
    exit 1
}

$runFinobjResult = Invoke-FinCommandCaptureFinobjOutput -Action {
    & $fin run --src $source --out $runOut --pipeline finobj --expect-exit 7
} -Label "fin run --pipeline finobj"
$runFinobjObj = $runFinobjResult.FinobjPath

Assert-FinobjTempArtifactCleaned -Path $buildFinobjObj -Label "build"
Assert-FinobjTempArtifactCleaned -Path $runFinobjObj -Label "run"

Finalize-TestTmpWorkspace -State $tmpState

Write-Host ("pipeline_direct_sha256={0}" -f $directHash)
Write-Host ("pipeline_finobj_sha256={0}" -f $finobjHash)
Write-Host "build pipeline finobj integration check passed."

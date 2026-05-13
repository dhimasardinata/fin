Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$runLinux = Join-Path $repoRoot "tests/integration/run_linux_elf.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
$finobjHelpers = Join-Path $repoRoot "tests/common/finobj_output_helpers.ps1"
. $tmpWorkspace
. $finobjHelpers

$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "examples-smoke-"
$tmpDir = $tmpState.TmpDir

$source = "examples/stage0/source_module_layout/main.fn"
$directOut = Join-Path $tmpDir "source-module-direct"
$finobjOut = Join-Path $tmpDir "source-module-finobj"
$runDirectOut = Join-Path $tmpDir "source-module-run-direct"
$runFinobjOut = Join-Path $tmpDir "source-module-run-finobj"

try {
    & $fin build --src $source --out $directOut --pipeline direct
    $buildFinobjResult = Invoke-FinCommandCaptureFinobjOutput -Action {
        & $fin build --src $source --out $finobjOut --pipeline finobj
    } -Label "example finobj build"
    $buildFinobjObj = $buildFinobjResult.FinobjPath

    & $verifyElf -Path $directOut -ExpectedExitCode 43
    & $verifyElf -Path $finobjOut -ExpectedExitCode 43
    & $runLinux -Path $directOut -ExpectedExitCode 43
    & $runLinux -Path $finobjOut -ExpectedExitCode 43

    $null = Assert-FileSha256Equal -LeftPath $directOut -RightPath $finobjOut -Label "source module example pipeline"

    & $fin run --src $source --out $runDirectOut --pipeline direct --expect-exit 43
    $runFinobjResult = Invoke-FinCommandCaptureFinobjOutput -Action {
        & $fin run --src $source --out $runFinobjOut --pipeline finobj --expect-exit 43
    } -Label "example finobj run"
    $runFinobjObj = $runFinobjResult.FinobjPath

    Assert-FinobjTempArtifactCleaned -Path $buildFinobjObj -Label "example build"
    Assert-FinobjTempArtifactCleaned -Path $runFinobjObj -Label "example run"
}
finally {
    Finalize-TestTmpWorkspace -State $tmpState
}

Write-Host "examples integration check passed."

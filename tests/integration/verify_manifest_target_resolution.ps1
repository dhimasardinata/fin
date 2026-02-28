Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$verifyPe = Join-Path $repoRoot "tests/bootstrap/verify_pe_exit0.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
$finobjHelpers = Join-Path $repoRoot "tests/common/finobj_output_helpers.ps1"
. $tmpWorkspace
. $finobjHelpers
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "manifest-target-smoke-"
$tmpDir = $tmpState.TmpDir

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

$project = Join-Path $tmpDir "manifest_target_proj"
$manifest = Join-Path $project "fin.toml"
$source = Join-Path $project "src/main.fn"
$winOut = Join-Path $tmpDir "main-manifest-win.exe"
$winFinobjOut = Join-Path $tmpDir "main-manifest-win-finobj.exe"
$runOut = Join-Path $tmpDir "main-manifest-run.exe"
$runFinobjOut = Join-Path $tmpDir "main-manifest-run-finobj.exe"
$linuxOverrideOut = Join-Path $tmpDir "main-target-override"
$linuxOverrideFinobjOut = Join-Path $tmpDir "main-target-override-finobj"
$missingManifest = Join-Path $tmpDir "missing-fin.toml"

& $fin init --dir $project --name manifest_target_proj

$manifestRaw = Get-Content -Path $manifest -Raw
$manifestUpdated = $manifestRaw -replace 'primary = "x86_64-linux-elf"', 'primary = "x86_64-windows-pe"'
Set-Content -Path $manifest -Value $manifestUpdated

& $fin build --manifest $manifest --src $source --out $winOut
$buildWinFinobjResult = Invoke-FinCommandCaptureFinobjOutput -Action {
    & $fin build --manifest $manifest --src $source --out $winFinobjOut --pipeline finobj
} -Label "fin build --manifest <win-primary> --pipeline finobj"
$buildWinFinobjObj = $buildWinFinobjResult.FinobjPath
& $verifyPe -Path $winOut -ExpectedExitCode 0
& $verifyPe -Path $winFinobjOut -ExpectedExitCode 0

& $fin run --manifest $manifest --src $source --out $runOut --expect-exit 0
$runWinFinobjResult = Invoke-FinCommandCaptureFinobjOutput -Action {
    & $fin run --manifest $manifest --src $source --out $runFinobjOut --pipeline finobj --expect-exit 0
} -Label "fin run --manifest <win-primary> --pipeline finobj"
$runWinFinobjObj = $runWinFinobjResult.FinobjPath
& $verifyPe -Path $runOut -ExpectedExitCode 0
& $verifyPe -Path $runFinobjOut -ExpectedExitCode 0

& $fin build --manifest $manifest --src $source --out $linuxOverrideOut --target x86_64-linux-elf
$buildLinuxFinobjResult = Invoke-FinCommandCaptureFinobjOutput -Action {
    & $fin build --manifest $manifest --src $source --out $linuxOverrideFinobjOut --target x86_64-linux-elf --pipeline finobj
} -Label "fin build --manifest <win-primary> --target x86_64-linux-elf --pipeline finobj"
$buildLinuxFinobjObj = $buildLinuxFinobjResult.FinobjPath
& $verifyElf -Path $linuxOverrideOut -ExpectedExitCode 0
& $verifyElf -Path $linuxOverrideFinobjOut -ExpectedExitCode 0

$winDirectHash = (Get-FileHash -Path $winOut -Algorithm SHA256).Hash.ToLowerInvariant()
$winFinobjHash = (Get-FileHash -Path $winFinobjOut -Algorithm SHA256).Hash.ToLowerInvariant()
if ($winDirectHash -ne $winFinobjHash) {
    Write-Error ("manifest primary windows pipeline mismatch: direct={0} finobj={1}" -f $winDirectHash, $winFinobjHash)
    exit 1
}

$linuxDirectHash = (Get-FileHash -Path $linuxOverrideOut -Algorithm SHA256).Hash.ToLowerInvariant()
$linuxFinobjHash = (Get-FileHash -Path $linuxOverrideFinobjOut -Algorithm SHA256).Hash.ToLowerInvariant()
if ($linuxDirectHash -ne $linuxFinobjHash) {
    Write-Error ("manifest target override pipeline mismatch: direct={0} finobj={1}" -f $linuxDirectHash, $linuxFinobjHash)
    exit 1
}

if (Test-Path $buildWinFinobjObj) {
    Write-Error ("Expected stage0 finobj temp artifact cleanup after manifest build (windows primary): {0}" -f $buildWinFinobjObj)
    exit 1
}
if (Test-Path $runWinFinobjObj) {
    Write-Error ("Expected stage0 finobj temp artifact cleanup after manifest run (windows primary): {0}" -f $runWinFinobjObj)
    exit 1
}
if (Test-Path $buildLinuxFinobjObj) {
    Write-Error ("Expected stage0 finobj temp artifact cleanup after manifest build (linux override): {0}" -f $buildLinuxFinobjObj)
    exit 1
}

Assert-Fails -Action {
    & $fin build --manifest $missingManifest --src $source --out (Join-Path $tmpDir "missing-manifest-out") | Out-Null
} -Label "explicit missing manifest path"

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "manifest target resolution integration check passed."

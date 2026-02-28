Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$verifyPe = Join-Path $repoRoot "tests/bootstrap/verify_pe_exit0.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace
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
$runOut = Join-Path $tmpDir "main-manifest-run.exe"
$linuxOverrideOut = Join-Path $tmpDir "main-target-override"
$missingManifest = Join-Path $tmpDir "missing-fin.toml"

& $fin init --dir $project --name manifest_target_proj

$manifestRaw = Get-Content -Path $manifest -Raw
$manifestUpdated = $manifestRaw -replace 'primary = "x86_64-linux-elf"', 'primary = "x86_64-windows-pe"'
Set-Content -Path $manifest -Value $manifestUpdated

& $fin build --manifest $manifest --src $source --out $winOut
& $verifyPe -Path $winOut -ExpectedExitCode 0

& $fin run --manifest $manifest --src $source --out $runOut --expect-exit 0
& $verifyPe -Path $runOut -ExpectedExitCode 0

& $fin build --manifest $manifest --src $source --out $linuxOverrideOut --target x86_64-linux-elf
& $verifyElf -Path $linuxOverrideOut -ExpectedExitCode 0

Assert-Fails -Action {
    & $fin build --manifest $missingManifest --src $source --out (Join-Path $tmpDir "missing-manifest-out") | Out-Null
} -Label "explicit missing manifest path"

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "manifest target resolution integration check passed."

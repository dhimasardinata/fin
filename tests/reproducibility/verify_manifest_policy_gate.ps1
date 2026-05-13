Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$policy = Join-Path $repoRoot "ci/verify_manifest.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "manifest-policy-gate-smoke-"
$tmpRoot = $tmpState.TmpDir
$manifest = Join-Path $tmpRoot "fin.toml"

function Write-Manifest {
    param(
        [string]$Name = "gate_smoke",
        [string]$Version = "0.1.0-dev",
        [string]$SeedHash = "UNSET",
        [string]$Primary = "x86_64-linux-elf",
        [string]$Secondary = "x86_64-windows-pe",
        [string]$Independent = "true",
        [string]$ExtPolicy = "true",
        [string]$ReproPolicy = "true"
    )

    Set-Content -Path $manifest -Value @"
[workspace]
name = "$Name"
version = "$Version"
independent = $Independent
seed_hash = "$SeedHash"

[targets]
primary = "$Primary"
secondary = "$Secondary"

[policy]
external_toolchain_forbidden = $ExtPolicy
reproducible_build_required = $ReproPolicy
"@
}

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
        Write-Error ("Expected manifest policy failure: {0}" -f $Label)
        exit 1
    }
}

# Should pass: valid baseline.
Write-Manifest
& $policy -Manifest $manifest

# Should fail: invalid workspace name.
Write-Manifest -Name "9bad"
Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "invalid workspace name"

# Should fail: empty workspace version.
Write-Manifest -Version ""
Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "empty workspace version"

# Should fail: invalid seed hash syntax.
Write-Manifest -SeedHash "NOT-A-HASH"
Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "invalid seed hash"

# Should fail: invalid primary target.
Write-Manifest -Primary "x86_64-linux-unknown"
Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "invalid primary target"

# Should fail: duplicated primary/secondary.
Write-Manifest -Primary "x86_64-linux-elf" -Secondary "x86_64-linux-elf"
Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "same primary and secondary"

# Should fail: policy switch disabled.
Write-Manifest -ExtPolicy "false"
Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "external toolchain policy false"

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "manifest policy gate self-check passed."

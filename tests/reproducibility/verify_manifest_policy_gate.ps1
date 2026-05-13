Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\\..")).Path
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
        [string]$ReproPolicy = "true",
        [string]$WorkspaceSection = "workspace",
        [string]$TargetsSection = "targets",
        [string]$PolicySection = "policy",
        [string]$NameKey = "name",
        [string]$SeedHashKey = "seed_hash",
        [string]$PrimaryKey = "primary",
        [string]$ExtPolicyKey = "external_toolchain_forbidden"
    )

    Set-Content -Path $manifest -Value @"
[$WorkspaceSection]
$NameKey = "$Name"
version = "$Version"
independent = $Independent
$SeedHashKey = "$SeedHash"

[$TargetsSection]
$PrimaryKey = "$Primary"
secondary = "$Secondary"

[$PolicySection]
$ExtPolicyKey = $ExtPolicy
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
        throw ("Expected manifest policy failure: {0}" -f $Label)
    }
}

try {
    # Should pass: valid baseline.
    Write-Manifest
    & $policy -Manifest $manifest

    # Should fail: invalid workspace name.
    Write-Manifest -Name "9bad"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "invalid workspace name"

    # Should fail: empty workspace version.
    Write-Manifest -Version ""
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "empty workspace version"

    # Should fail: wrong-case required sections and keys.
    Write-Manifest -WorkspaceSection "Workspace"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "wrong-case workspace section"

    Write-Manifest -TargetsSection "Targets"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "wrong-case targets section"

    Write-Manifest -PolicySection "Policy"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "wrong-case policy section"

    Write-Manifest -NameKey "Name"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "wrong-case workspace name key"

    Write-Manifest -SeedHashKey "Seed_Hash"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "wrong-case seed hash key"

    Write-Manifest -PrimaryKey "Primary"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "wrong-case target primary key"

    Write-Manifest -ExtPolicyKey "External_Toolchain_Forbidden"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "wrong-case policy key"

    # Should fail: invalid seed hash syntax.
    Write-Manifest -SeedHash "NOT-A-HASH"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "invalid seed hash"

    Write-Manifest -SeedHash "unset"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "lowercase unset seed hash"

    Write-Manifest -SeedHash ("A" * 64)
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "uppercase seed hash"

    # Should fail: invalid dependency name.
    Write-Manifest
    Add-Content -Path $manifest -Value @"

[dependencies]
bad.name = "1.0.0"
"@
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "invalid dependency name"

    # Should fail: empty dependency version.
    Write-Manifest
    Add-Content -Path $manifest -Value @"

[dependencies]
serde = ""
"@
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "empty dependency version"

    # Should fail: invalid primary target.
    Write-Manifest -Primary "x86_64-linux-unknown"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "invalid primary target"

    Write-Manifest -Primary "X86_64-linux-elf"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "uppercase primary target"

    Write-Manifest -Secondary "X86_64-windows-pe"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "uppercase secondary target"

    # Should fail: duplicated primary/secondary.
    Write-Manifest -Primary "x86_64-linux-elf" -Secondary "x86_64-linux-elf"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "same primary and secondary"

    # Should fail: uppercase booleans are not canonical TOML policy values.
    Write-Manifest -Independent "TRUE"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "uppercase workspace independent"

    Write-Manifest -ExtPolicy "TRUE"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "uppercase external toolchain policy"

    Write-Manifest -ReproPolicy "TRUE"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "uppercase reproducible build policy"

    # Should fail: policy switch disabled.
    Write-Manifest -ExtPolicy "false"
    Assert-Fails -Action { & $policy -Manifest $manifest | Out-Null } -Label "external toolchain policy false"
}
finally {
    Finalize-TestTmpWorkspace -State $tmpState
}

Write-Host "manifest policy gate self-check passed."

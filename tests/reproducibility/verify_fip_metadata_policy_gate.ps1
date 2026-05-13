Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$policy = Join-Path $repoRoot "ci/verify_fip_metadata.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace

$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "fip-metadata-policy-gate-"
$tmpRoot = $tmpState.TmpDir

function Assert-Passes {
    param(
        [scriptblock]$Action,
        [string]$Label
    )

    try {
        & $Action | Out-Null
    }
    catch {
        Write-Error ("Expected FIP metadata policy pass: {0}" -f $Label)
        exit 1
    }
}

function Assert-Fails {
    param(
        [scriptblock]$Action,
        [string]$Label
    )

    $failed = $false
    try {
        & $Action | Out-Null
    }
    catch {
        $failed = $true
    }

    if (-not $failed) {
        Write-Error ("Expected FIP metadata policy failure: {0}" -f $Label)
        exit 1
    }
}

function Write-MinimalFipRepo {
    param(
        [string]$Status = "Accepted",
        [string]$Requires = "[]",
        [string]$ImplementationBlock = @"
- implementation:
  - README.md
"@,
        [string]$AcceptanceBlock = @"
- acceptance:
  - Minimal policy passes.
"@,
        [string]$AuthorsLine = "- authors: @fin-maintainers",
        [string]$CreatedLine = "- created: 2026-02-27",
        [string]$TargetRelease = "M0",
        [string]$Discussion = "TBD",
        [string]$CompatibilityBody = "Minimal.",
        [switch]$CreateReadme
    )

    Remove-Item -Recurse -Force (Join-Path $tmpRoot "*") -ErrorAction SilentlyContinue

    New-Item -ItemType Directory -Path (Join-Path $tmpRoot "fips") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tmpRoot ".github/workflows") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tmpRoot "cmd/fin") -Force | Out-Null

    if ($CreateReadme) {
        Set-Content -Path (Join-Path $tmpRoot "README.md") -Value "# Minimal"
    }

    $labelRows = @(
        "Draft",
        "Review",
        "Accepted",
        "Scheduled",
        "InProgress",
        "Implemented",
        "Released",
        "Deferred",
        "Rejected"
    ) | ForEach-Object {
        '  {{ "name": "status/{0}", "color": "000000", "description": "{1}" }}' -f $_.ToLowerInvariant(), $_
    }
    Set-Content -Path (Join-Path $tmpRoot ".github/labels.json") -Value ("[`n{0}`n]" -f ($labelRows -join ",`n"))
    Set-Content -Path (Join-Path $tmpRoot ".github/workflows/ci.yml") -Value "run: ./ci/verify_fip_metadata.ps1"
    Set-Content -Path (Join-Path $tmpRoot "cmd/fin/fin.ps1") -Value "ci/verify_fip_metadata.ps1"

    Set-Content -Path (Join-Path $tmpRoot "fips/INDEX.md") -Value @"
# FIP Index

| ID | Title | Status | Address |
|---|---|---|---|
| FIP-0001 | Minimal Policy | $Status | ``fin://fip/FIP-0001`` |
"@

    Set-Content -Path (Join-Path $tmpRoot "fips/FIP-0001-minimal-policy.md") -Value @"
# FIP-0001: Minimal Policy

- id: FIP-0001
- address: fin://fip/FIP-0001
- status: $Status
$AuthorsLine
$CreatedLine
- requires: $Requires
- target_release: $TargetRelease
- discussion: $Discussion
$ImplementationBlock
$AcceptanceBlock

## Summary

Minimal.

## Motivation

Minimal.

## Design

Minimal.

## Alternatives

Minimal.

## Risks

Minimal.

## Compatibility

$CompatibilityBody

## Test Plan

Minimal.
"@
}

try {
    Write-MinimalFipRepo -CreateReadme
    Assert-Passes -Label "valid minimal FIP repo" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -AuthorsLine "" -CreateReadme
    Assert-Fails -Label "missing authors metadata" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -CreatedLine "- created: 2026-2-27" -CreateReadme
    Assert-Fails -Label "created metadata with non-canonical date format" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -CreatedLine "- created: 2026-02-30" -CreateReadme
    Assert-Fails -Label "created metadata with invalid date" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -AcceptanceBlock "- acceptance:" -CreateReadme
    Assert-Fails -Label "empty acceptance metadata block" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -TargetRelease "milestone-0" -CreateReadme
    Assert-Fails -Label "invalid target_release metadata" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -ImplementationBlock @"
- implementation:
  - missing.md
"@
    Assert-Fails -Label "missing implementation path" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -Requires '["FIP-9999"]' -CreateReadme
    Assert-Fails -Label "unknown requires FIP" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -Requires '["not-a-fip"]' -CreateReadme
    Assert-Fails -Label "invalid requires FIP format" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -ImplementationBlock "- implementation: []"
    Assert-Fails -Label "accepted FIP with empty implementation list" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -ImplementationBlock @"
- implementation:
  - ../README.md
"@
    Assert-Fails -Label "parent traversal implementation path" -Action { & $policy -Root $tmpRoot }

    $absoluteImplementation = [System.IO.Path]::GetFullPath((Join-Path $tmpRoot "absolute.md"))
    Write-MinimalFipRepo -ImplementationBlock @"
- implementation:
  - $absoluteImplementation
"@
    Assert-Fails -Label "absolute implementation path" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -Status "Draft" -ImplementationBlock "- implementation: []"
    Assert-Passes -Label "draft FIP with empty implementation list" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -Status "Implemented" -Discussion "fin://fip/FIP-0001" -CreateReadme
    Assert-Passes -Label "implemented FIP with completed discussion and compatibility" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -Status "Implemented" -CreateReadme
    Assert-Fails -Label "implemented FIP with discussion placeholder" -Action { & $policy -Root $tmpRoot }

    Write-MinimalFipRepo -Status "Implemented" -Discussion "fin://fip/FIP-0001" -CompatibilityBody "Compatibility impact must be documented before Implemented status." -CreateReadme
    Assert-Fails -Label "implemented FIP with compatibility placeholder" -Action { & $policy -Root $tmpRoot }
}
finally {
    Finalize-TestTmpWorkspace -State $tmpState
}

Write-Host "FIP metadata policy gate self-check passed."

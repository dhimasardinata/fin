Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$policy = Join-Path $repoRoot "ci/check_fip_link.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "fip-link-policy-gate-smoke-"
$tmpRoot = $tmpState.TmpDir
$fipRoot = Join-Path $tmpRoot "fips"
New-Item -ItemType Directory -Path $fipRoot -Force | Out-Null

function Write-Fip {
    param(
        [string]$Id,
        [string]$Slug,
        [string]$Status
    )

    Set-Content -Path (Join-Path $fipRoot ("{0}-{1}.md" -f $Id, $Slug)) -Value @"
# ${Id}: synthetic

- id: $Id
- address: fin://fip/$Id
- status: $Status
- authors: @test
- created: 2026-05-13
- requires: []
- target_release: test
- discussion: test
- implementation: []
- acceptance:
  - synthetic
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
        Write-Error ("Expected FIP link policy failure: {0}" -f $Label)
        exit 1
    }
}

$featureFiles = "compiler/finc/stage0/parse_main_exit.ps1"

Write-Fip -Id "FIP-9001" -Slug "accepted" -Status "Accepted"
Write-Fip -Id "FIP-9002" -Slug "scheduled" -Status "Scheduled"
Write-Fip -Id "FIP-9003" -Slug "draft" -Status "Draft"
Write-Fip -Id "FIP-9004" -Slug "inprogress" -Status "InProgress"
Write-Fip -Id "FIP-9005" -Slug "implemented" -Status "Implemented"
Write-Fip -Id "FIP-9006" -Slug "rejected" -Status "Rejected"

& $policy -FipRoot $fipRoot -Title "Docs only" -Body "" -ChangedFiles "docs/architecture.md"
& $policy -FipRoot $fipRoot -Title "Feature FIP-9001" -Body "" -ChangedFiles $featureFiles
& $policy -FipRoot $fipRoot -Title "Feature FIP-9002" -Body "" -ChangedFiles $featureFiles

Assert-Fails -Action {
    & $policy -FipRoot $fipRoot -Title "Feature without link" -Body "" -ChangedFiles $featureFiles | Out-Null
} -Label "missing FIP link"

Assert-Fails -Action {
    & $policy -FipRoot $fipRoot -Title "Feature FIP-9999" -Body "" -ChangedFiles $featureFiles | Out-Null
} -Label "unknown linked FIP"

Assert-Fails -Action {
    & $policy -FipRoot $fipRoot -Title "Feature FIP-9003" -Body "" -ChangedFiles $featureFiles | Out-Null
} -Label "draft linked FIP"

Assert-Fails -Action {
    & $policy -FipRoot $fipRoot -Title "Feature FIP-9005" -Body "" -ChangedFiles $featureFiles | Out-Null
} -Label "implemented FIP without same-PR FIP change"

Assert-Fails -Action {
    & $policy -FipRoot $fipRoot -Title "Feature FIP-9006" -Body "" -ChangedFiles ($featureFiles + "`nfips/FIP-9006-rejected.md") | Out-Null
} -Label "rejected FIP even when changed"

& $policy -FipRoot $fipRoot -Title "Feature FIP-9004" -Body "" -ChangedFiles ($featureFiles + "`nfips/FIP-9004-inprogress.md")
& $policy -FipRoot $fipRoot -Title "Feature FIP-9005" -Body "" -ChangedFiles ($featureFiles + "`nfips/FIP-9005-implemented.md")

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "FIP link policy gate self-check passed."

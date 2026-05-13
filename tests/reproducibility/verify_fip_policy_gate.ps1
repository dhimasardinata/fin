Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$policy = Join-Path $repoRoot "ci/check_fip_link.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace

$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "fip-policy-gate-"
$tmpRoot = $tmpState.TmpDir
$tmpFipDir = Join-Path $tmpRoot "fips"

function Assert-Passes {
    param(
        [scriptblock]$Action,
        [string]$Label
    )

    try {
        & $Action | Out-Null
    }
    catch {
        Write-Error ("Expected FIP policy pass: {0}" -f $Label)
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
        Write-Error ("Expected FIP policy failure: {0}" -f $Label)
        exit 1
    }
}

function Write-MinimalFip {
    param(
        [string]$FipId,
        [string]$Status
    )

    New-Item -ItemType Directory -Path $tmpFipDir -Force | Out-Null
    Set-Content -Path (Join-Path $tmpFipDir ("{0}-policy-gate.md" -f $FipId)) -Value @"
# ${FipId}: Policy Gate

- id: $FipId
- address: fin://fip/$FipId
- status: $Status
- authors: @fin-maintainers
- created: 2026-02-27
- requires: []
- target_release: M0
- discussion: TBD
- implementation: []
- acceptance:
  - Minimal.
"@
}

try {
    Assert-Passes -Label "docs-only change without FIP" -Action {
        & $policy -Title "docs: update readme" -Body "" -ChangedFiles "README.md"
    }

    Assert-Fails -Label "feature change without FIP" -Action {
        & $policy -Title "feat: change compiler" -Body "" -ChangedFiles "compiler/finc/stage0/parse_main_exit.ps1"
    }

    Assert-Fails -Label "CI policy change without FIP" -Action {
        & $policy -Title "ci: change policy gate" -Body "" -ChangedFiles "ci/check_fip_link.ps1"
    }

    Assert-Fails -Label "workflow policy change without FIP" -Action {
        & $policy -Title "ci: change workflow gate" -Body "" -ChangedFiles ".github/workflows/ci.yml"
    }

    Assert-Fails -Label "feature change with missing FIP" -Action {
        & $policy -Title "feat: change compiler FIP-9999" -Body "" -ChangedFiles "compiler/finc/stage0/parse_main_exit.ps1"
    }

    Assert-Fails -Label "feature change with ineligible review FIP" -Action {
        & $policy -Title "feat: add stdlib path" -Body "Refs FIP-0017" -ChangedFiles "runtime/README.md"
    }

    Assert-Passes -Label "feature change with accepted FIP" -Action {
        & $policy -Title "feat: update charter" -Body "Refs FIP-0001" -ChangedFiles "SPEC.md"
    }

    Assert-Passes -Label "CI policy change with accepted FIP" -Action {
        & $policy -Title "ci: update gate" -Body "Refs FIP-0002" -ChangedFiles "ci/check_fip_link.ps1"
    }

    Assert-Passes -Label "feature change with in-progress FIP" -Action {
        & $policy -Title "feat: update source model" -Body "Refs FIP-0004" -ChangedFiles "compiler/finc/stage0/parse_main_exit.ps1"
    }

    Assert-Passes -Label "feature change with implemented FIP" -Action {
        & $policy -Title "feat: update grammar" -Body "Refs FIP-0005" -ChangedFiles "cmd/fin/fin.ps1"
    }

    Write-MinimalFip -FipId "FIP-0100" -Status "Accepted"
    Assert-Passes -Label "feature change with temp accepted FIP" -Action {
        & $policy -Title "feat: temp gate" -Body "Refs FIP-0100" -ChangedFiles "cmd/fin/fin.ps1" -FipDir $tmpFipDir
    }

    Write-MinimalFip -FipId "FIP-0101" -Status "accepted"
    Assert-Fails -Label "feature change with lowercase accepted FIP status" -Action {
        & $policy -Title "feat: temp gate" -Body "Refs FIP-0101" -ChangedFiles "cmd/fin/fin.ps1" -FipDir $tmpFipDir
    }

    Write-MinimalFip -FipId "FIP-0102" -Status "ACCEPTED"
    Assert-Fails -Label "feature change with uppercase accepted FIP status" -Action {
        & $policy -Title "feat: temp gate" -Body "Refs FIP-0102" -ChangedFiles "cmd/fin/fin.ps1" -FipDir $tmpFipDir
    }
}
finally {
    Finalize-TestTmpWorkspace -State $tmpState
}

Write-Host "FIP policy gate self-check passed."

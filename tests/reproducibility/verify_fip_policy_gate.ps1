Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$policy = Join-Path $repoRoot "ci/check_fip_link.ps1"

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

Assert-Passes -Label "docs-only change without FIP" -Action {
    & $policy -Title "docs: update readme" -Body "" -ChangedFiles "README.md"
}

Assert-Fails -Label "feature change without FIP" -Action {
    & $policy -Title "feat: change compiler" -Body "" -ChangedFiles "compiler/finc/stage0/parse_main_exit.ps1"
}

Assert-Fails -Label "feature change with missing FIP" -Action {
    & $policy -Title "feat: change compiler FIP-9999" -Body "" -ChangedFiles "compiler/finc/stage0/parse_main_exit.ps1"
}

Assert-Fails -Label "feature change with draft FIP" -Action {
    & $policy -Title "feat: add stdlib path" -Body "Refs FIP-0017" -ChangedFiles "runtime/README.md"
}

Assert-Passes -Label "feature change with accepted FIP" -Action {
    & $policy -Title "feat: update charter" -Body "Refs FIP-0001" -ChangedFiles "SPEC.md"
}

Assert-Passes -Label "feature change with in-progress FIP" -Action {
    & $policy -Title "feat: update source model" -Body "Refs FIP-0004" -ChangedFiles "compiler/finc/stage0/parse_main_exit.ps1"
}

Assert-Passes -Label "feature change with implemented FIP" -Action {
    & $policy -Title "feat: update grammar" -Body "Refs FIP-0005" -ChangedFiles "cmd/fin/fin.ps1"
}

Write-Host "FIP policy gate self-check passed."

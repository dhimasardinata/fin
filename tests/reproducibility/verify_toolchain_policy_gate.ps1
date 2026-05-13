Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$policy = Join-Path $repoRoot "ci/forbid_external_toolchain.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "policy-gate-smoke-"
$tmpRoot = $tmpState.TmpDir
$workflows = Join-Path $tmpRoot ".github/workflows"
$workflowFile = Join-Path $workflows "ci.yml"

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
        Write-Error ("Expected toolchain policy failure: {0}" -f $Label)
        exit 1
    }
}

$missingRoot = Join-Path $tmpRoot "missing-root"
Assert-Fails -Action { & $policy -Root $missingRoot | Out-Null } -Label "missing policy root"

$emptyRoot = Join-Path $tmpRoot "empty-root"
New-Item -ItemType Directory -Path $emptyRoot -Force | Out-Null
& $policy -Root $emptyRoot

New-Item -ItemType Directory -Path $workflows -Force | Out-Null

# Should fail: disallowed toolchain command in workflow.
Set-Content -Path $workflowFile -Value @"
name: ci
jobs:
  bad:
    runs-on: ubuntu-latest
    steps:
      - run: gcc --version
"@

Assert-Fails -Action { & $policy -Root $tmpRoot | Out-Null } -Label "disallowed workflow command"

# Should fail: disallowed command matching is case-insensitive.
Set-Content -Path $workflowFile -Value @"
name: ci
jobs:
  bad:
    runs-on: ubuntu-latest
    steps:
      - run: GCC --version
"@

Assert-Fails -Action { & $policy -Root $tmpRoot | Out-Null } -Label "uppercase disallowed workflow command"

# Should pass: allow-tagged line for controlled exception.
Set-Content -Path $workflowFile -Value @"
name: ci
jobs:
  allowed:
    runs-on: ubuntu-latest
    steps:
      - run: gcc --version # fin-ci-allow-external
"@

& $policy -Root $tmpRoot

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "toolchain policy gate self-check passed."

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

$failed = $false
try {
    & $policy -Root $tmpRoot | Out-Null
}
catch {
    $failed = $true
}

if (-not $failed) {
    Write-Error "Expected policy gate to fail for disallowed workflow command."
    exit 1
}

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

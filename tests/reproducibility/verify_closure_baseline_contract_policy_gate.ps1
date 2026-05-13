Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$policy = Join-Path $repoRoot "tests/reproducibility/verify_closure_baseline_contract.ps1"
$sourceBaseline = Join-Path $repoRoot "seed/stage0-closure-baseline.txt"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace

$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "closure-baseline-contract-policy-gate-"
$tmpRoot = $tmpState.TmpDir
$tmpBaseline = Join-Path $tmpRoot "stage0-closure-baseline.txt"
$pwsh = (Get-Process -Id $PID).Path
$validBaselineLines = @(Get-Content -LiteralPath $sourceBaseline)

function Write-BaselineLines {
    param([string[]]$Lines)

    Set-Content -Path $tmpBaseline -Value $Lines
}

function Set-BaselineValue {
    param(
        [string]$Key,
        [string]$Value
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $validBaselineLines) {
        if ($line -cmatch ("^{0}=" -f [regex]::Escape($Key))) {
            $lines.Add(("{0}={1}" -f $Key, $Value))
            continue
        }
        $lines.Add($line)
    }
    return $lines.ToArray()
}

function Rename-BaselineKey {
    param(
        [string]$OldKey,
        [string]$NewKey
    )

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $validBaselineLines) {
        if ($line -cmatch ("^{0}=" -f [regex]::Escape($OldKey))) {
            $lines.Add(($line -creplace ("^{0}=" -f [regex]::Escape($OldKey)), ("{0}=" -f $NewKey)))
            continue
        }
        $lines.Add($line)
    }
    return $lines.ToArray()
}

function Get-BaselineValue {
    param([string]$Key)

    $line = $validBaselineLines | Where-Object { $_ -cmatch ("^{0}=" -f [regex]::Escape($Key)) } | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($line)) {
        throw ("missing source baseline key: {0}" -f $Key)
    }
    return ($line -creplace ("^{0}=" -f [regex]::Escape($Key)), "")
}

function Invoke-BaselinePolicy {
    & $pwsh -NoLogo -NoProfile -File $policy -Baseline $tmpBaseline *>&1 | Out-Null
    return $LASTEXITCODE
}

function Assert-Passes {
    param([string]$Label)

    $exitCode = Invoke-BaselinePolicy
    if ($exitCode -ne 0) {
        Write-Error ("Expected closure baseline contract pass: {0}" -f $Label)
        exit 1
    }
}

function Assert-Fails {
    param([string]$Label)

    $exitCode = Invoke-BaselinePolicy
    if ($exitCode -eq 0) {
        Write-Error ("Expected closure baseline contract failure: {0}" -f $Label)
        exit 1
    }
}

try {
    Write-BaselineLines -Lines $validBaselineLines
    Assert-Passes -Label "valid committed baseline shape"

    Write-BaselineLines -Lines (Rename-BaselineKey -OldKey "closure_mode" -NewKey "Closure_mode")
    Assert-Fails -Label "wrong-case baseline key"

    Write-BaselineLines -Lines (Set-BaselineValue -Key "closure_mode" -Value "STAGE0-PROXY")
    Assert-Fails -Label "wrong-case closure mode"

    Write-BaselineLines -Lines (Set-BaselineValue -Key "seed_declared_sha256" -Value "unset")
    Assert-Fails -Label "lowercase unset seed declaration"

    $upperSeedSnapshot = (Get-BaselineValue -Key "seed_snapshot_sha256").ToUpperInvariant()
    Write-BaselineLines -Lines (Set-BaselineValue -Key "seed_snapshot_sha256" -Value $upperSeedSnapshot)
    Assert-Fails -Label "uppercase seed snapshot hash"

    Write-BaselineLines -Lines (Set-BaselineValue -Key "linux_pipeline_parity" -Value "TRUE")
    Assert-Fails -Label "uppercase parity boolean"
}
finally {
    Finalize-TestTmpWorkspace -State $tmpState
}

Write-Host "closure baseline contract policy gate self-check passed."

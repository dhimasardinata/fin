Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$closureCheck = Join-Path $repoRoot "tests/bootstrap/verify_stage0_closure.ps1"
$workspaceHelper = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $workspaceHelper

$closureRoot = Join-Path $repoRoot ("artifacts/closure-policy-{0}" -f $PID)
$savedKeep = $env:FIN_KEEP_CLOSURE_RUNS
$savedStale = $env:FIN_CLOSURE_STALE_HOURS
$pwshPath = (Get-Command pwsh).Source
$activeProc = $null
$inactiveProc = $null

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if (-not $Condition) {
        Write-Error $Message
        exit 1
    }
}

function Assert-False {
    param(
        [bool]$Condition,
        [string]$Message
    )

    if ($Condition) {
        Write-Error $Message
        exit 1
    }
}

function Assert-Throws {
    param(
        [scriptblock]$Action,
        [string]$Message
    )

    $failed = $false
    try {
        & $Action
    }
    catch {
        $failed = $true
    }

    if (-not $failed) {
        Write-Error $Message
        exit 1
    }
}

function Set-ClosureOwnerMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceDir,
        [Parameter(Mandatory = $true)]
        [int]$OwnerPid,
        [Parameter(Mandatory = $true)]
        [datetime]$OwnerStartUtc
    )

    $metadataPath = Join-Path $WorkspaceDir ".fin-closure-owner.json"
    $payload = [ordered]@{
        pid = [int]$OwnerPid
        start_utc = $OwnerStartUtc.ToUniversalTime().ToString("o")
    } | ConvertTo-Json -Compress
    Set-Content -Path $metadataPath -Value $payload -NoNewline
}

function Set-WorkspaceStale {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    (Get-Item $Path).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddHours(-3)
}

try {
    if (Test-Path $closureRoot) {
        Remove-Item -Recurse -Force $closureRoot
    }
    New-Item -ItemType Directory -Path $closureRoot -Force | Out-Null

    # Case 1: invalid env config must fail fast before closure build work.
    $env:FIN_KEEP_CLOSURE_RUNS = "true"
    Assert-Throws -Action { & $closureCheck -OutDir $closureRoot } -Message "Expected invalid FIN_KEEP_CLOSURE_RUNS to fail."
    Remove-Item Env:FIN_KEEP_CLOSURE_RUNS -ErrorAction SilentlyContinue

    Remove-Item Env:FIN_KEEP_CLOSURE_RUNS -ErrorAction SilentlyContinue
    $env:FIN_CLOSURE_STALE_HOURS = "0"
    Assert-Throws -Action { & $closureCheck -OutDir $closureRoot } -Message "Expected invalid FIN_CLOSURE_STALE_HOURS to fail."
    Remove-Item Env:FIN_CLOSURE_STALE_HOURS -ErrorAction SilentlyContinue

    $env:FIN_KEEP_CLOSURE_RUNS = "1"
    $env:FIN_CLOSURE_STALE_HOURS = "0"
    Assert-Throws -Action { & $closureCheck -OutDir $closureRoot } -Message "Expected invalid FIN_CLOSURE_STALE_HOURS to fail even when FIN_KEEP_CLOSURE_RUNS=1."
    Remove-Item Env:FIN_KEEP_CLOSURE_RUNS -ErrorAction SilentlyContinue
    Remove-Item Env:FIN_CLOSURE_STALE_HOURS -ErrorAction SilentlyContinue

    # Case 2: stale pruning with owner metadata safety and legacy fallback/backfill.
    $activeProc = Start-Process -FilePath $pwshPath -ArgumentList "-NoLogo", "-NoProfile", "-Command", "Start-Sleep -Seconds 40" -PassThru
    $activePid = $activeProc.Id
    $activeStartUtc = $activeProc.StartTime.ToUniversalTime()

    $inactiveProc = Start-Process -FilePath $pwshPath -ArgumentList "-NoLogo", "-NoProfile", "-Command", "Start-Sleep -Seconds 1" -PassThru
    $inactivePid = $inactiveProc.Id
    $inactiveStartUtc = $inactiveProc.StartTime.ToUniversalTime()
    Wait-Process -Id $inactivePid

    $activeLegacyDir = Join-Path $closureRoot ("run-{0}-legacy-active" -f $activePid)
    $activeInvalidDir = Join-Path $closureRoot ("run-{0}-invalid-metadata" -f $activePid)
    $activeMismatchDir = Join-Path $closureRoot ("run-{0}-mismatched-metadata" -f $activePid)
    $inactiveLegacyDir = Join-Path $closureRoot ("run-{0}-legacy-inactive" -f $inactivePid)
    $inactiveMetadataDir = Join-Path $closureRoot ("run-{0}-metadata-inactive" -f $inactivePid)
    $malformedRunDir = Join-Path $closureRoot "run-bad-format"

    New-Item -ItemType Directory -Path $activeLegacyDir -Force | Out-Null
    New-Item -ItemType Directory -Path $activeInvalidDir -Force | Out-Null
    New-Item -ItemType Directory -Path $activeMismatchDir -Force | Out-Null
    New-Item -ItemType Directory -Path $inactiveLegacyDir -Force | Out-Null
    New-Item -ItemType Directory -Path $inactiveMetadataDir -Force | Out-Null
    New-Item -ItemType Directory -Path $malformedRunDir -Force | Out-Null

    Set-Content -Path (Join-Path $activeInvalidDir ".fin-closure-owner.json") -Value "{bad-json" -NoNewline
    Set-ClosureOwnerMetadata -WorkspaceDir $activeMismatchDir -OwnerPid $activePid -OwnerStartUtc $activeStartUtc.AddMinutes(-5)
    Set-ClosureOwnerMetadata -WorkspaceDir $inactiveMetadataDir -OwnerPid $inactivePid -OwnerStartUtc $inactiveStartUtc
    Set-ClosureOwnerMetadata -WorkspaceDir $malformedRunDir -OwnerPid $activePid -OwnerStartUtc $activeStartUtc

    Set-WorkspaceStale -Path $activeLegacyDir
    Set-WorkspaceStale -Path $activeInvalidDir
    Set-WorkspaceStale -Path $activeMismatchDir
    Set-WorkspaceStale -Path $inactiveLegacyDir
    Set-WorkspaceStale -Path $inactiveMetadataDir
    Set-WorkspaceStale -Path $malformedRunDir

    $env:FIN_CLOSURE_STALE_HOURS = "1"
    Remove-Item Env:FIN_KEEP_CLOSURE_RUNS -ErrorAction SilentlyContinue
    & $closureCheck -OutDir $closureRoot | Out-Null

    Assert-True -Condition (Test-Path $activeLegacyDir) -Message "Expected active legacy closure dir to be preserved."
    Assert-True -Condition (Test-Path $activeInvalidDir) -Message "Expected active invalid-metadata closure dir to be preserved via PID fallback."
    Assert-False -Condition (Test-Path $activeMismatchDir) -Message "Expected active mismatched-metadata closure dir to be pruned."
    Assert-False -Condition (Test-Path $inactiveLegacyDir) -Message "Expected inactive legacy closure dir to be pruned."
    Assert-False -Condition (Test-Path $inactiveMetadataDir) -Message "Expected inactive metadata closure dir to be pruned."
    Assert-False -Condition (Test-Path $malformedRunDir) -Message "Expected malformed run-name closure dir to be pruned."

    $activeLegacyMetadata = Join-Path $activeLegacyDir ".fin-closure-owner.json"
    $activeInvalidMetadata = Join-Path $activeInvalidDir ".fin-closure-owner.json"
    Assert-True -Condition (Test-Path $activeLegacyMetadata) -Message "Expected active legacy closure dir to receive owner metadata backfill."
    Assert-True -Condition (Test-Path $activeInvalidMetadata) -Message "Expected active invalid-metadata closure dir to receive metadata repair."

    $legacyStatus = Get-TestTmpWorkspaceOwnerMetadataStatus -MetadataPath $activeLegacyMetadata -ExpectedPid $activePid
    $invalidStatus = Get-TestTmpWorkspaceOwnerMetadataStatus -MetadataPath $activeInvalidMetadata -ExpectedPid $activePid
    Assert-True -Condition ([bool]$legacyStatus.Valid) -Message "Expected backfilled legacy closure metadata to be valid."
    Assert-True -Condition ([bool]$legacyStatus.Active) -Message "Expected backfilled legacy closure metadata to resolve active owner."
    Assert-True -Condition ([bool]$invalidStatus.Valid) -Message "Expected repaired closure metadata to be valid."
    Assert-True -Condition ([bool]$invalidStatus.Active) -Message "Expected repaired closure metadata to resolve active owner."

    # Case 3: keep mode bypasses stale-prune cleanup across consecutive runs.
    $keepBypassStaleDir = Join-Path $closureRoot "run-999999-keep-bypass-stale"
    New-Item -ItemType Directory -Path $keepBypassStaleDir -Force | Out-Null
    Set-WorkspaceStale -Path $keepBypassStaleDir

    $env:FIN_CLOSURE_STALE_HOURS = "1"
    $env:FIN_KEEP_CLOSURE_RUNS = "1"
    & $closureCheck -OutDir $closureRoot | Out-Null
    Assert-True -Condition (Test-Path $keepBypassStaleDir) -Message "Expected stale closure dir to be retained when FIN_KEEP_CLOSURE_RUNS=1."

    # Keep-mode bypass must remain stable across repeated invocations.
    Set-WorkspaceStale -Path $keepBypassStaleDir
    & $closureCheck -OutDir $closureRoot | Out-Null
    Assert-True -Condition (Test-Path $keepBypassStaleDir) -Message "Expected stale closure dir to remain retained across consecutive runs when FIN_KEEP_CLOSURE_RUNS=1."

    Remove-Item Env:FIN_KEEP_CLOSURE_RUNS -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $keepBypassStaleDir -ErrorAction SilentlyContinue
}
finally {
    if ($null -eq $savedKeep) {
        Remove-Item Env:FIN_KEEP_CLOSURE_RUNS -ErrorAction SilentlyContinue
    }
    else {
        $env:FIN_KEEP_CLOSURE_RUNS = $savedKeep
    }

    if ($null -eq $savedStale) {
        Remove-Item Env:FIN_CLOSURE_STALE_HOURS -ErrorAction SilentlyContinue
    }
    else {
        $env:FIN_CLOSURE_STALE_HOURS = $savedStale
    }

    if ($null -ne $activeProc -and -not $activeProc.HasExited) {
        Stop-Process -Id $activeProc.Id -Force -ErrorAction SilentlyContinue
    }
    if ($null -ne $inactiveProc -and -not $inactiveProc.HasExited) {
        Stop-Process -Id $inactiveProc.Id -Force -ErrorAction SilentlyContinue
    }

    if (Test-Path $closureRoot) {
        Remove-Item -Recurse -Force $closureRoot -ErrorAction SilentlyContinue
    }
}

Write-Host "closure workspace policy check passed."

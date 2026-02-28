Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$workspaceHelper = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $workspaceHelper

$tmpRoot = Join-Path $repoRoot "artifacts/tmp"
$prefix = "tmp-policy-"
$savedKeep = $env:FIN_KEEP_TEST_TMP
$savedStale = $env:FIN_TEST_TMP_STALE_HOURS
$pwshPath = (Get-Command pwsh).Source
$activeProc = $null
$activePidDir = $null

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

try {
    if (-not (Test-Path $tmpRoot)) {
        New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
    }

    # Case 1: Default behavior creates and removes the PID-scoped workspace.
    Remove-Item Env:FIN_KEEP_TEST_TMP -ErrorAction SilentlyContinue
    Remove-Item Env:FIN_TEST_TMP_STALE_HOURS -ErrorAction SilentlyContinue
    $stateDefault = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix $prefix
    Assert-True -Condition (Test-Path $stateDefault.TmpDir) -Message "Expected default workspace to be created."
    Finalize-TestTmpWorkspace -State $stateDefault
    Assert-False -Condition (Test-Path $stateDefault.TmpDir) -Message "Expected default workspace to be removed on finalize."

    # Case 2: Keep mode retains temp artifacts for local debugging.
    $env:FIN_KEEP_TEST_TMP = "1"
    $stateKeep = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix $prefix
    Assert-True -Condition (Test-Path $stateKeep.TmpDir) -Message "Expected keep-mode workspace to be created."
    Finalize-TestTmpWorkspace -State $stateKeep
    Assert-True -Condition (Test-Path $stateKeep.TmpDir) -Message "Expected keep-mode workspace to be retained."
    Remove-Item -Recurse -Force $stateKeep.TmpDir
    Remove-Item Env:FIN_KEEP_TEST_TMP -ErrorAction SilentlyContinue

    # Case 3: Stale pruning removes stale dirs, keeps recent dirs, and keeps active PID-owned dirs.
    $env:FIN_TEST_TMP_STALE_HOURS = "1"
    $staleDir = Join-Path $tmpRoot ("{0}stale-manual" -f $prefix)
    $recentDir = Join-Path $tmpRoot ("{0}recent-manual" -f $prefix)
    if (-not (Test-Path $staleDir)) {
        New-Item -ItemType Directory -Path $staleDir -Force | Out-Null
    }
    if (-not (Test-Path $recentDir)) {
        New-Item -ItemType Directory -Path $recentDir -Force | Out-Null
    }
    $activeProc = Start-Process -FilePath $pwshPath -ArgumentList "-NoLogo", "-NoProfile", "-Command", "Start-Sleep -Seconds 30" -PassThru
    $activePidDir = Join-Path $tmpRoot ("{0}{1}" -f $prefix, $activeProc.Id)
    if (-not (Test-Path $activePidDir)) {
        New-Item -ItemType Directory -Path $activePidDir -Force | Out-Null
    }
    $activeStartUtc = Get-TestTmpWorkspaceProcessStartUtc -OwnerPid $activeProc.Id
    Set-TestTmpWorkspaceOwnerMetadata -TmpDir $activePidDir -OwnerPid $activeProc.Id -OwnerStartUtc $activeStartUtc
    (Get-Item $staleDir).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddHours(-3)
    (Get-Item $recentDir).LastWriteTimeUtc = (Get-Date).ToUniversalTime()
    (Get-Item $activePidDir).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddHours(-3)

    $statePrune = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix $prefix
    Assert-False -Condition (Test-Path $staleDir) -Message "Expected stale temp dir to be pruned."
    Assert-True -Condition (Test-Path $recentDir) -Message "Expected recent temp dir to be preserved."
    Assert-True -Condition (Test-Path $activePidDir) -Message "Expected active PID temp dir to be preserved."
    Finalize-TestTmpWorkspace -State $statePrune
    Remove-Item -Recurse -Force $recentDir
    Remove-Item Env:FIN_TEST_TMP_STALE_HOURS -ErrorAction SilentlyContinue

    # Case 4: Active PID dir with mismatched owner metadata is treated as stale and pruned.
    $env:FIN_TEST_TMP_STALE_HOURS = "1"
    Set-TestTmpWorkspaceOwnerMetadata -TmpDir $activePidDir -OwnerPid $activeProc.Id -OwnerStartUtc $activeStartUtc.AddMinutes(-5)
    (Get-Item $activePidDir).LastWriteTimeUtc = (Get-Date).ToUniversalTime().AddHours(-3)
    $stateMismatch = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix $prefix
    Assert-False -Condition (Test-Path $activePidDir) -Message "Expected mismatched owner metadata dir to be pruned."
    Finalize-TestTmpWorkspace -State $stateMismatch
    Remove-Item Env:FIN_TEST_TMP_STALE_HOURS -ErrorAction SilentlyContinue

    # Case 5: Invalid stale-hours config must fail fast.
    $env:FIN_TEST_TMP_STALE_HOURS = "0"
    Assert-Throws -Action { Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix $prefix } -Message "Expected invalid FIN_TEST_TMP_STALE_HOURS to fail."
    Remove-Item Env:FIN_TEST_TMP_STALE_HOURS -ErrorAction SilentlyContinue
}
finally {
    if ($null -eq $savedKeep) {
        Remove-Item Env:FIN_KEEP_TEST_TMP -ErrorAction SilentlyContinue
    }
    else {
        $env:FIN_KEEP_TEST_TMP = $savedKeep
    }

    if ($null -eq $savedStale) {
        Remove-Item Env:FIN_TEST_TMP_STALE_HOURS -ErrorAction SilentlyContinue
    }
    else {
        $env:FIN_TEST_TMP_STALE_HOURS = $savedStale
    }

    if ($null -ne $activeProc -and -not $activeProc.HasExited) {
        Stop-Process -Id $activeProc.Id -Force -ErrorAction SilentlyContinue
    }
    if ($null -ne $activePidDir -and (Test-Path $activePidDir)) {
        Remove-Item -Recurse -Force $activePidDir -ErrorAction SilentlyContinue
    }

    Get-ChildItem -Path $tmpRoot -Directory -Filter ("{0}*" -f $prefix) -ErrorAction SilentlyContinue |
        ForEach-Object {
            Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue
        }
}

Write-Host "test tmp workspace policy check passed."

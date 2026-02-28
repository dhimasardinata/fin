Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Initialize-TestTmpWorkspace {
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,
        [Parameter(Mandatory = $true)]
        [string]$Prefix
    )

    if ([string]::IsNullOrWhiteSpace($Prefix) -or $Prefix -notmatch '^[A-Za-z0-9._-]+-$') {
        throw ("Invalid test tmp prefix: {0}" -f $Prefix)
    }

    $tmpRoot = Join-Path $RepoRoot "artifacts/tmp"
    $tmpDir = Join-Path $tmpRoot ("{0}{1}" -f $Prefix, $PID)
    $keepTmp = ($env:FIN_KEEP_TEST_TMP -eq "1")
    [int]$tmpStaleHours = 6
    if (-not [string]::IsNullOrWhiteSpace($env:FIN_TEST_TMP_STALE_HOURS)) {
        [int]$parsedStaleHours = 0
        if (-not [int]::TryParse($env:FIN_TEST_TMP_STALE_HOURS, [ref]$parsedStaleHours) -or $parsedStaleHours -lt 1) {
            throw ("FIN_TEST_TMP_STALE_HOURS must be a positive integer, found: {0}" -f $env:FIN_TEST_TMP_STALE_HOURS)
        }
        $tmpStaleHours = $parsedStaleHours
    }
    $staleCutoffUtc = (Get-Date).ToUniversalTime().AddHours(-1 * $tmpStaleHours)

    if (-not (Test-Path $tmpRoot)) {
        New-Item -ItemType Directory -Path $tmpRoot -Force | Out-Null
    }
    if (-not $keepTmp) {
        Get-ChildItem -Path $tmpRoot -Directory -Filter ("{0}*" -f $Prefix) -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -ne $tmpDir -and $_.LastWriteTimeUtc -lt $staleCutoffUtc } |
            ForEach-Object {
                Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue
            }
    }

    if (Test-Path $tmpDir) {
        Remove-Item -Recurse -Force $tmpDir
    }
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

    return [pscustomobject]@{
        TmpDir = [string]$tmpDir
        KeepTmp = [bool]$keepTmp
    }
}

function Finalize-TestTmpWorkspace {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$State
    )

    $tmpDir = [string]$State.TmpDir
    $keepTmp = [bool]$State.KeepTmp

    if ($keepTmp) {
        Write-Host ("tmp_dir_retained={0}" -f $tmpDir)
    }
    elseif (Test-Path $tmpDir) {
        Remove-Item -Recurse -Force $tmpDir
    }
}

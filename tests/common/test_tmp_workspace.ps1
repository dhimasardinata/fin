Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TestTmpWorkspaceProcessStartUtc {
    param(
        [Parameter(Mandatory = $true)]
        [int]$OwnerPid
    )

    $proc = Get-Process -Id $OwnerPid -ErrorAction Stop
    return $proc.StartTime.ToUniversalTime()
}

function Set-TestTmpWorkspaceOwnerMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TmpDir,
        [Parameter(Mandatory = $true)]
        [int]$OwnerPid,
        [Parameter(Mandatory = $true)]
        [datetime]$OwnerStartUtc
    )

    $metadataPath = Join-Path $TmpDir ".fin-tmp-owner.json"
    $payload = [ordered]@{
        pid = [int]$OwnerPid
        start_utc = $OwnerStartUtc.ToUniversalTime().ToString("o")
    } | ConvertTo-Json -Compress
    Set-Content -Path $metadataPath -Value $payload -NoNewline
}

function Test-TestTmpWorkspacePidActive {
    param(
        [Parameter(Mandatory = $true)]
        [int]$OwnerPid
    )

    try {
        return $null -ne (Get-Process -Id $OwnerPid -ErrorAction Stop)
    }
    catch {
        return $false
    }
}

function Get-TestTmpWorkspaceOwnerMetadataStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MetadataPath,
        [Parameter(Mandatory = $true)]
        [int]$ExpectedPid
    )

    $status = [pscustomobject]@{
        Valid = $false
        Active = $false
    }

    $raw = Get-Content -Path $MetadataPath -Raw -ErrorAction Stop
    $pidRaw = ""
    $startRaw = ""
    $doc = $null
    try {
        $doc = [System.Text.Json.JsonDocument]::Parse($raw)
        $root = $doc.RootElement
        $pidRaw = $root.GetProperty("pid").ToString()
        $startRaw = $root.GetProperty("start_utc").GetString()
    }
    catch {
        return $status
    }
    finally {
        if ($null -ne $doc) {
            $doc.Dispose()
        }
    }

    [int]$metadataPid = 0
    if (-not [int]::TryParse([string]$pidRaw, [ref]$metadataPid) -or $metadataPid -lt 1) {
        return $status
    }

    if ([string]::IsNullOrWhiteSpace($startRaw)) {
        return $status
    }

    try {
        $metadataStartUtc = [datetime]::Parse($startRaw, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
    }
    catch {
        return $status
    }

    $status.Valid = $true
    if ($metadataPid -ne $ExpectedPid) {
        return $status
    }

    try {
        $processStartUtc = Get-TestTmpWorkspaceProcessStartUtc -OwnerPid $metadataPid
    }
    catch {
        return $status
    }

    $status.Active = ([math]::Abs(($processStartUtc - $metadataStartUtc).TotalSeconds) -lt 2)
    return $status
}

function Test-TestTmpWorkspaceOwnerActive {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$Directory,
        [Parameter(Mandatory = $true)]
        [string]$Prefix
    )

    $pidMatch = [regex]::Match($Directory.Name, ("^{0}(?<pid>[0-9]+)$" -f [regex]::Escape($Prefix)))
    if (-not $pidMatch.Success) {
        return $false
    }

    [int]$ownerPid = 0
    if (-not [int]::TryParse($pidMatch.Groups["pid"].Value, [ref]$ownerPid) -or $ownerPid -lt 1) {
        return $false
    }

    $pidIsActive = Test-TestTmpWorkspacePidActive -OwnerPid $ownerPid
    $metadataPath = Join-Path $Directory.FullName ".fin-tmp-owner.json"
    if (Test-Path $metadataPath) {
        try {
            $metadataStatus = Get-TestTmpWorkspaceOwnerMetadataStatus -MetadataPath $metadataPath -ExpectedPid $ownerPid
            if (-not [bool]$metadataStatus.Valid) {
                return $pidIsActive
            }
            return [bool]$metadataStatus.Active
        }
        catch {
            return $pidIsActive
        }
    }

    return $pidIsActive
}

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
            Where-Object {
                $_.FullName -ne $tmpDir -and
                $_.LastWriteTimeUtc -lt $staleCutoffUtc -and
                -not (Test-TestTmpWorkspaceOwnerActive -Directory $_ -Prefix $Prefix)
            } |
            ForEach-Object {
                Remove-Item -Recurse -Force $_.FullName -ErrorAction SilentlyContinue
            }
    }

    if (Test-Path $tmpDir) {
        Remove-Item -Recurse -Force $tmpDir
    }
    New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    Set-TestTmpWorkspaceOwnerMetadata -TmpDir $tmpDir -OwnerPid $PID -OwnerStartUtc (Get-TestTmpWorkspaceProcessStartUtc -OwnerPid $PID)

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

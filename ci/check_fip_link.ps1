param(
    [string]$Title = "",
    [string]$Body = "",
    [string]$ChangedFiles = "",
    [string]$FipDir = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$requirePattern = "(^|[^A-Z0-9])(FIP-[0-9]{4})([^0-9]|$)"
$eligibleStatuses = @("Accepted", "Scheduled", "InProgress", "Implemented", "Released")
$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
if ([string]::IsNullOrWhiteSpace($FipDir)) {
    $FipDir = Join-Path $repoRoot "fips"
}

function Get-FipStatus {
    param([string]$FipId)

    $matches = @(Get-ChildItem -LiteralPath $FipDir -File -Filter ("{0}-*.md" -f $FipId) -ErrorAction SilentlyContinue)
    if ($matches.Count -ne 1) {
        return ""
    }

    $text = Get-Content -LiteralPath $matches[0].FullName -Raw
    $statusMatch = [regex]::Match($text, '(?m)^-\s+status:\s+([A-Za-z]+)\s*$')
    if (-not $statusMatch.Success) {
        return ""
    }

    return $statusMatch.Groups[1].Value
}

$files = @()
if ($ChangedFiles) {
    $files = $ChangedFiles -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

$featureTouched = $false
foreach ($f in $files) {
    if ($f -match "^(compiler/|runtime/|std/|cmd/|ci/|\.github/workflows/|SPEC\.md|fin\.toml)") {
        $featureTouched = $true
        break
    }
}

if (-not $featureTouched) {
    Write-Host "No feature-critical files changed; FIP link not required."
    exit 0
}

$text = "$Title`n$Body"
$matches = [regex]::Matches($text, $requirePattern)
if ($matches.Count -eq 0) {
    Write-Error "Feature changes require a linked FIP-#### in PR title or body."
    exit 1
}

$seenFips = @{}
$ineligible = @()
foreach ($match in $matches) {
    $fipId = $match.Groups[2].Value
    if ($seenFips.ContainsKey($fipId)) {
        continue
    }
    $seenFips[$fipId] = $true

    $status = Get-FipStatus -FipId $fipId
    if ([string]::IsNullOrWhiteSpace($status)) {
        $ineligible += ("{0}:missing" -f $fipId)
        continue
    }

    if ($eligibleStatuses -contains $status) {
        Write-Host ("FIP link check passed: {0} status={1}" -f $fipId, $status)
        exit 0
    }

    $ineligible += ("{0}:{1}" -f $fipId, $status)
}

Write-Error ("Feature changes require a linked FIP in eligible status ({0}); found: {1}" -f ($eligibleStatuses -join ","), ($ineligible -join ", "))
exit 1

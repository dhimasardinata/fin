param(
    [string]$Title = "",
    [string]$Body = "",
    [string]$ChangedFiles = "",
    [string]$FipRoot = "fips"
)

$requirePattern = "(^|[^A-Z0-9])(FIP-[0-9]{4})([^0-9]|$)"
$allowedReadyStatuses = @("Accepted", "Scheduled")
$allowedSamePrStatuses = @("InProgress", "Implemented", "Released")
$knownStatuses = @("Draft", "Review", "Accepted", "Scheduled", "InProgress", "Implemented", "Released", "Deferred", "Rejected")

function Fail-FipLink {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

$files = @()
if ($ChangedFiles) {
    $files = $ChangedFiles -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
}

$featureTouched = $false
foreach ($f in $files) {
    if ($f -match "^(compiler/|runtime/|std/|cmd/|SPEC\.md|fin\.toml)") {
        $featureTouched = $true
        break
    }
}

if (-not $featureTouched) {
    Write-Host "No feature-critical files changed; FIP link not required."
    exit 0
}

$text = "$Title`n$Body"
$linkedFips = @(
    [regex]::Matches($text, $requirePattern) |
        ForEach-Object { [string]$_.Groups[2].Value } |
        Sort-Object -Unique
)

if ($linkedFips.Count -eq 0) {
    Fail-FipLink "Feature changes require a linked FIP-#### in PR title or body."
}

if (-not (Test-Path $FipRoot)) {
    Fail-FipLink "Missing FIP root: $FipRoot"
}

function Get-LinkedFipStatus {
    param([string]$FipId)

    $fipFiles = @(Get-ChildItem -Path $FipRoot -Filter ("{0}-*.md" -f $FipId) -File -ErrorAction SilentlyContinue)
    if ($fipFiles.Count -eq 0) {
        Fail-FipLink ("Linked FIP does not exist: {0}" -f $FipId)
    }
    if ($fipFiles.Count -gt 1) {
        Fail-FipLink ("Linked FIP is ambiguous: {0}" -f $FipId)
    }

    $fipText = Get-Content -LiteralPath $fipFiles[0].FullName -Raw
    if ($fipText -notmatch "(?m)^-\s*status:\s*`?([A-Za-z]+)`?\s*$") {
        Fail-FipLink ("Linked FIP missing status metadata: {0}" -f $FipId)
    }

    $status = [string]$Matches[1]
    if ($knownStatuses -notcontains $status) {
        Fail-FipLink ("Linked FIP has unknown status: {0} ({1})" -f $FipId, $status)
    }

    return $status
}

function Test-LinkedFipChanged {
    param([string]$FipId)

    foreach ($file in $files) {
        $leaf = Split-Path -Path ($file -replace "\\", "/") -Leaf
        if ($leaf -like ("{0}-*.md" -f $FipId)) {
            return $true
        }
    }

    return $false
}

$validLinks = @()
$invalidLinks = @()
foreach ($fipId in $linkedFips) {
    $status = Get-LinkedFipStatus -FipId $fipId
    if ($allowedReadyStatuses -contains $status) {
        $validLinks += ("{0} ({1})" -f $fipId, $status)
        continue
    }

    if (($allowedSamePrStatuses -contains $status) -and (Test-LinkedFipChanged -FipId $fipId)) {
        $validLinks += ("{0} ({1}, changed in this PR)" -f $fipId, $status)
        continue
    }

    $invalidLinks += ("{0} ({1})" -f $fipId, $status)
}

if ($validLinks.Count -eq 0) {
    Fail-FipLink ("Feature changes require a linked FIP in Accepted or Scheduled status, or a same-PR status transition for the linked FIP. Found: {0}" -f ($invalidLinks -join ", "))
}

Write-Host ("FIP link check passed: {0}" -f ($validLinks -join ", "))

param(
    [string]$Title = "",
    [string]$Body = "",
    [string]$ChangedFiles = ""
)

$requirePattern = "(^|[^A-Z0-9])(FIP-[0-9]{4})([^0-9]|$)"

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
if ($text -notmatch $requirePattern) {
    Write-Error "Feature changes require a linked FIP-#### in PR title or body."
    exit 1
}

Write-Host "FIP link check passed."

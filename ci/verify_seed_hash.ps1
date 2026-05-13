param(
    [string]$Manifest = "seed/manifest.toml",
    [string]$Sums = "seed/SHA256SUMS",
    [switch]$RequireSet
)

function Fail-SeedMetadata {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

function Get-ManifestStringValue {
    param(
        [string]$Content,
        [string]$Key
    )

    $pattern = "(?m)^\s*{0}\s*=\s*`"([^`"]+)`"\s*$" -f [regex]::Escape($Key)
    $matches = [regex]::Matches($Content, $pattern)
    if ($matches.Count -ne 1) {
        Fail-SeedMetadata ("manifest.toml must contain exactly one {0} field" -f $Key)
    }

    return [string]$matches[0].Groups[1].Value
}

function Assert-SeedHashValue {
    param(
        [string]$Hash,
        [string]$Label
    )

    if ($Hash -eq "UNSET") {
        return
    }

    if ($Hash -notmatch "^[0-9a-fA-F]{64}$") {
        Fail-SeedMetadata ("{0} must be UNSET or a 64-character SHA256 hex value" -f $Label)
    }
}

if (-not (Test-Path $Manifest)) {
    Fail-SeedMetadata "Missing manifest: $Manifest"
}

if (-not (Test-Path $Sums)) {
    Fail-SeedMetadata "Missing hash file: $Sums"
}

$manifestContent = Get-Content -LiteralPath $Manifest -Raw
$artifactPath = Get-ManifestStringValue -Content $manifestContent -Key "path"
$manifestHash = Get-ManifestStringValue -Content $manifestContent -Key "sha256"
Assert-SeedHashValue -Hash $manifestHash -Label "manifest sha256"

$entries = @()
$lineNumber = 0
foreach ($line in Get-Content -LiteralPath $Sums) {
    $lineNumber += 1
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
        continue
    }

    if ($trimmed -notmatch "^(\S+)\s+(.+)$") {
        Fail-SeedMetadata ("Invalid SHA256SUMS entry at line {0}" -f $lineNumber)
    }

    $entryHash = [string]$Matches[1]
    $entryPath = ([string]$Matches[2]).Trim()
    Assert-SeedHashValue -Hash $entryHash -Label ("SHA256SUMS line {0}" -f $lineNumber)

    if ($entryPath -eq $artifactPath) {
        $entries += [pscustomobject]@{
            Hash = $entryHash
            Path = $entryPath
            Line = $lineNumber
        }
    }
}

if ($entries.Count -eq 0) {
    Fail-SeedMetadata ("SHA256SUMS missing artifact path: {0}" -f $artifactPath)
}

if ($entries.Count -gt 1) {
    Fail-SeedMetadata ("SHA256SUMS contains duplicate artifact path: {0}" -f $artifactPath)
}

$sumsHash = [string]$entries[0].Hash
if ($manifestHash -ne $sumsHash) {
    Fail-SeedMetadata ("seed manifest sha256 does not match SHA256SUMS for {0}" -f $artifactPath)
}

if ($RequireSet) {
    if ($manifestHash -eq "UNSET") {
        Fail-SeedMetadata "Seed hash is UNSET but RequireSet was specified"
    }
}

if ($manifestHash -ne "UNSET") {
    if (-not (Test-Path $artifactPath)) {
        Fail-SeedMetadata ("Seed artifact is missing: {0}" -f $artifactPath)
    }

    $actualHash = (Get-FileHash -Path $artifactPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($actualHash -ne $manifestHash.ToLowerInvariant()) {
        Fail-SeedMetadata ("Seed artifact hash mismatch for {0}" -f $artifactPath)
    }
}

Write-Host "Seed hash metadata check passed."

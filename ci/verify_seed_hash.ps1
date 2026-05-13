param(
    [string]$Manifest = "seed/manifest.toml",
    [string]$Sums = "seed/SHA256SUMS",
    [switch]$RequireSet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail-SeedHash {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

if (-not (Test-Path $Manifest)) {
    Fail-SeedHash "Missing manifest: $Manifest"
}

if (-not (Test-Path $Sums)) {
    Fail-SeedHash "Missing hash file: $Sums"
}

function Get-ManifestStringField {
    param(
        [string]$Text,
        [string]$Key,
        [string]$Label
    )

    $match = [regex]::Match($Text, ("(?m)^\s*{0}\s*=\s*`"([^`"]+)`"\s*$" -f [regex]::Escape($Key)))
    if (-not $match.Success) {
        Fail-SeedHash ("manifest.toml missing {0} field" -f $Label)
    }

    return $match.Groups[1].Value.Trim()
}

function Get-ManifestBoolField {
    param(
        [string]$Text,
        [string]$Key,
        [string]$Label
    )

    $match = [regex]::Match($Text, ("(?m)^\s*{0}\s*=\s*(\S+)\s*$" -f [regex]::Escape($Key)))
    if (-not $match.Success) {
        Fail-SeedHash ("manifest.toml missing {0} field" -f $Label)
    }

    return $match.Groups[1].Value.Trim()
}

function Assert-SeedRelativePath {
    param(
        [string]$Value,
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Fail-SeedHash ("{0} path is empty" -f $Label)
    }

    if ([System.IO.Path]::IsPathRooted($Value) -or $Value -match '\\' -or $Value -match '(^|/)\.\.(/|$)' -or $Value -match '(^|/)\.(/|$)' -or $Value -match '//') {
        Fail-SeedHash ("{0} path must be a safe repository-relative '/' path: {1}" -f $Label, $Value)
    }
}

function Assert-SeedHashValue {
    param(
        [string]$Value,
        [string]$Label
    )

    if ($Value -ceq "UNSET") {
        return
    }

    if ($Value -cnotmatch '^[0-9a-f]{64}$') {
        Fail-SeedHash ("{0} must be UNSET or a lowercase SHA-256 hex digest, found: {1}" -f $Label, $Value)
    }
}

$manifestFull = (Resolve-Path -LiteralPath $Manifest).Path
$sumsFull = (Resolve-Path -LiteralPath $Sums).Path
$seedDir = Split-Path -Parent $manifestFull
$repoRoot = Split-Path -Parent $seedDir

$manifestContent = Get-Content -LiteralPath $manifestFull -Raw
$sumsContent = Get-Content -LiteralPath $sumsFull -Raw

$seedName = Get-ManifestStringField -Text $manifestContent -Key "name" -Label "seed name"
$seedVersion = Get-ManifestStringField -Text $manifestContent -Key "version" -Label "seed version"
$artifactPath = Get-ManifestStringField -Text $manifestContent -Key "path" -Label "artifact path"
$manifestHash = Get-ManifestStringField -Text $manifestContent -Key "sha256" -Label "sha256"
$artifactFormat = Get-ManifestStringField -Text $manifestContent -Key "format" -Label "format"
$immutablePerRelease = Get-ManifestBoolField -Text $manifestContent -Key "immutable_per_release" -Label "immutable_per_release"
$reviewRequired = Get-ManifestBoolField -Text $manifestContent -Key "review_required" -Label "review_required"

if ($seedName -cne "fin-seed") {
    Fail-SeedHash ("manifest.toml seed name must be fin-seed, found: {0}" -f $seedName)
}

if ($seedVersion -cnotmatch '^[0-9]+\.[0-9]+\.[0-9]+$') {
    Fail-SeedHash ("manifest.toml seed version must be <major>.<minor>.<patch>, found: {0}" -f $seedVersion)
}

Assert-SeedRelativePath -Value $artifactPath -Label "manifest artifact"
Assert-SeedHashValue -Value $manifestHash -Label "manifest sha256"

if ($artifactFormat -cne "native-binary") {
    Fail-SeedHash ("manifest.toml unsupported artifact format: {0}" -f $artifactFormat)
}

if ($immutablePerRelease -cne "true") {
    Fail-SeedHash ("manifest.toml immutable_per_release must be canonical true, found: {0}" -f $immutablePerRelease)
}

if ($reviewRequired -cne "true") {
    Fail-SeedHash ("manifest.toml review_required must be canonical true, found: {0}" -f $reviewRequired)
}

$sumRows = [System.Collections.Generic.List[object]]::new()
foreach ($line in [regex]::Split($sumsContent, "`r?`n")) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed) -or $trimmed.StartsWith("#")) {
        continue
    }

    $match = [regex]::Match($trimmed, '^(\S+)\s+(.+?)\s*$')
    if (-not $match.Success) {
        Fail-SeedHash ("Invalid SHA256SUMS line: {0}" -f $line)
    }

    $rowHash = $match.Groups[1].Value.Trim()
    $rowPath = $match.Groups[2].Value.Trim()
    Assert-SeedHashValue -Value $rowHash -Label "SHA256SUMS hash"
    Assert-SeedRelativePath -Value $rowPath -Label "SHA256SUMS artifact"

    $sumRows.Add([pscustomobject]@{
        Hash = $rowHash
        Path = $rowPath
    }) | Out-Null
}

if ($sumRows.Count -eq 0) {
    Fail-SeedHash "SHA256SUMS contains no hash rows"
}

$matchingRows = @($sumRows | Where-Object { $_.Path -ceq $artifactPath })
if ($matchingRows.Count -eq 0) {
    Fail-SeedHash ("SHA256SUMS missing manifest artifact path: {0}" -f $artifactPath)
}

if ($matchingRows.Count -gt 1) {
    Fail-SeedHash ("SHA256SUMS contains duplicate manifest artifact path: {0}" -f $artifactPath)
}

if ($matchingRows[0].Hash -cne $manifestHash) {
    Fail-SeedHash ("manifest sha256 does not match SHA256SUMS for {0}" -f $artifactPath)
}

if ($RequireSet) {
    if ($manifestHash -ceq "UNSET") {
        Fail-SeedHash "Seed hash is UNSET but RequireSet was specified"
    }

    if (@($sumRows | Where-Object { $_.Hash -ceq "UNSET" }).Count -gt 0) {
        Fail-SeedHash "SHA256SUMS contains UNSET but RequireSet was specified"
    }
}

$artifactFull = Join-Path $repoRoot $artifactPath
if ($manifestHash -ceq "UNSET") {
    if (Test-Path -LiteralPath $artifactFull) {
        Fail-SeedHash ("Seed artifact exists but manifest sha256 is UNSET: {0}" -f $artifactPath)
    }
}
else {
    if (-not (Test-Path -LiteralPath $artifactFull)) {
        Fail-SeedHash ("Seed artifact not found for configured hash: {0}" -f $artifactPath)
    }

    $actualHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifactFull).Hash.ToLowerInvariant()
    if ($actualHash -cne $manifestHash) {
        Fail-SeedHash ("Seed artifact hash mismatch for {0}: expected={1} actual={2}" -f $artifactPath, $manifestHash, $actualHash)
    }
}

Write-Host "Seed hash metadata check passed."

param(
    [string]$Manifest = "seed/manifest.toml",
    [string]$Sums = "seed/SHA256SUMS",
    [switch]$RequireSet
)

if (-not (Test-Path $Manifest)) {
    Write-Error "Missing manifest: $Manifest"
    exit 1
}

if (-not (Test-Path $Sums)) {
    Write-Error "Missing hash file: $Sums"
    exit 1
}

$manifestContent = Get-Content $Manifest -Raw
$sumsContent = Get-Content $Sums -Raw

if ($manifestContent -notmatch 'sha256\s*=\s*"([^"]+)"') {
    Write-Error "manifest.toml missing sha256 field"
    exit 1
}

$manifestHash = $Matches[1]

if ($RequireSet) {
    if ($manifestHash -eq "UNSET") {
        Write-Error "Seed hash is UNSET but RequireSet was specified"
        exit 1
    }
    if ($sumsContent -match "UNSET") {
        Write-Error "SHA256SUMS contains UNSET but RequireSet was specified"
        exit 1
    }
}

Write-Host "Seed hash metadata check passed."

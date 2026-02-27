param(
    [string]$Manifest = "fin.toml"
)

if (-not (Test-Path $Manifest)) {
    Write-Error "Missing $Manifest"
    exit 1
}

$content = Get-Content $Manifest -Raw

$required = @(
    'independent = true',
    'external_toolchain_forbidden = true',
    'reproducible_build_required = true'
)

foreach ($needle in $required) {
    if ($content -notmatch [regex]::Escape($needle)) {
        Write-Error "Missing required manifest policy line: $needle"
        exit 1
    }
}

Write-Host "Manifest policy check passed."

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$tmpDir = Join-Path $repoRoot "artifacts/tmp/pkg-smoke"
$manifest = Join-Path $tmpDir "fin.toml"

if (Test-Path $tmpDir) {
    Remove-Item -Recurse -Force $tmpDir
}

& $fin init --dir $tmpDir --name pkg_smoke

& $fin pkg add serde --version 1.2.3 --manifest $manifest
$content = Get-Content -Path $manifest -Raw
if ($content -notmatch '(?m)^\[dependencies\]\s*$') {
    Write-Error "Missing [dependencies] section after pkg add."
    exit 1
}
if ($content -notmatch '(?m)^serde\s*=\s*"1\.2\.3"\s*$') {
    Write-Error "Expected serde dependency with version 1.2.3."
    exit 1
}

# Add with inline version syntax.
& $fin pkg add http@2.0.0 --manifest $manifest
$content = Get-Content -Path $manifest -Raw
if ($content -notmatch '(?m)^http\s*=\s*"2\.0\.0"\s*$') {
    Write-Error "Expected http dependency with version 2.0.0."
    exit 1
}

# Update existing dependency.
& $fin pkg add serde --version 3.0.0 --manifest $manifest
$content = Get-Content -Path $manifest -Raw
if ($content -notmatch '(?m)^serde\s*=\s*"3\.0\.0"\s*$') {
    Write-Error "Expected serde dependency to update to 3.0.0."
    exit 1
}

# Invalid package name should fail.
$failed = $false
try {
    & $fin pkg add "bad.name" --manifest $manifest | Out-Null
}
catch {
    $failed = $true
}
if (-not $failed) {
    Write-Error "Expected pkg add to fail for invalid package name."
    exit 1
}

Write-Host "pkg integration check passed."

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$tmpDir = Join-Path $repoRoot "artifacts/tmp/pkg-smoke"
$manifest = Join-Path $tmpDir "fin.toml"
$lock = Join-Path $tmpDir "fin.lock"

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
$lockContent = Get-Content -Path $lock -Raw
if ($lockContent -notmatch '(?m)^version\s*=\s*1\s*$') {
    Write-Error "Expected lockfile version entry."
    exit 1
}
if ($lockContent -notmatch '(?m)^\s*\{\s*name\s*=\s*"serde",\s*version\s*=\s*"1\.2\.3"\s*\}\s*$') {
    Write-Error "Expected serde dependency in fin.lock."
    exit 1
}

# Add with inline version syntax.
& $fin pkg add http@2.0.0 --manifest $manifest
$content = Get-Content -Path $manifest -Raw
if ($content -notmatch '(?m)^http\s*=\s*"2\.0\.0"\s*$') {
    Write-Error "Expected http dependency with version 2.0.0."
    exit 1
}
$lockContent = Get-Content -Path $lock -Raw
$httpIndex = $lockContent.IndexOf('{ name = "http", version = "2.0.0" }')
$serdeIndex = $lockContent.IndexOf('{ name = "serde", version = "1.2.3" }')
if ($httpIndex -lt 0 -or $serdeIndex -lt 0) {
    Write-Error "Expected both http and serde entries in fin.lock."
    exit 1
}
if ($httpIndex -gt $serdeIndex) {
    Write-Error "Expected deterministic alphabetical order in fin.lock (http before serde)."
    exit 1
}

# Update existing dependency.
& $fin pkg add serde --version 3.0.0 --manifest $manifest
$content = Get-Content -Path $manifest -Raw
if ($content -notmatch '(?m)^serde\s*=\s*"3\.0\.0"\s*$') {
    Write-Error "Expected serde dependency to update to 3.0.0."
    exit 1
}
$lockContent = Get-Content -Path $lock -Raw
if ($lockContent -notmatch '(?m)^\s*\{\s*name\s*=\s*"serde",\s*version\s*=\s*"3\.0\.0"\s*\}\s*$') {
    Write-Error "Expected serde dependency update in fin.lock."
    exit 1
}

$hashBefore = (Get-FileHash -Path $lock -Algorithm SHA256).Hash
& $fin pkg add serde --version 3.0.0 --manifest $manifest
$hashAfter = (Get-FileHash -Path $lock -Algorithm SHA256).Hash
if ($hashBefore -ne $hashAfter) {
    Write-Error "Expected deterministic lockfile content for idempotent pkg add."
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

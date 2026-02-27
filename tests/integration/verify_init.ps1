Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$tmpDir = Join-Path $repoRoot "artifacts/tmp/init-smoke"

if (Test-Path $tmpDir) {
    Remove-Item -Recurse -Force $tmpDir
}

& $fin init --dir $tmpDir --name smoke_init

$manifest = Join-Path $tmpDir "fin.toml"
$lock = Join-Path $tmpDir "fin.lock"
$mainFn = Join-Path $tmpDir "src/main.fn"

foreach ($path in @($manifest, $lock, $mainFn)) {
    if (-not (Test-Path $path)) {
        Write-Error "Expected scaffold file missing: $path"
        exit 1
    }
}

$manifestContent = Get-Content $manifest -Raw
if ($manifestContent -notmatch 'name = "smoke_init"') {
    Write-Error "fin.toml does not contain expected project name."
    exit 1
}

$mainContent = Get-Content $mainFn -Raw
if ($mainContent -notmatch 'fn\s+main\s*\(\)') {
    Write-Error "src/main.fn missing main function."
    exit 1
}

# Second init without --force must fail.
$failed = $false
try {
    & $fin init --dir $tmpDir --name smoke_init | Out-Null
}
catch {
    $failed = $true
}

if (-not $failed) {
    Write-Error "Expected init to fail when files already exist without --force."
    exit 1
}

# Force should succeed.
& $fin init --dir $tmpDir --name smoke_init --force

Write-Host "init scaffold integration check passed."

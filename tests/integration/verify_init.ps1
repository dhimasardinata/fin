Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "init-smoke-"
$tmpDir = $tmpState.TmpDir
$projectDir = Join-Path $tmpDir "smoke_init"

& $fin init --dir $projectDir --name smoke_init

$manifest = Join-Path $projectDir "fin.toml"
$lock = Join-Path $projectDir "fin.lock"
$mainFn = Join-Path $projectDir "src/main.fn"

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
    & $fin init --dir $projectDir --name smoke_init | Out-Null
}
catch {
    $failed = $true
}

if (-not $failed) {
    Write-Error "Expected init to fail when files already exist without --force."
    exit 1
}

# Force should succeed.
& $fin init --dir $projectDir --name smoke_init --force

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "init scaffold integration check passed."

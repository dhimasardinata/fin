Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "pkg-publish-smoke-"
$tmpDir = $tmpState.TmpDir
$manifest = Join-Path $tmpDir "fin.toml"
$sourceDir = Join-Path $tmpDir "src"
$outDir = Join-Path $tmpDir "publish"
$artifact = Join-Path $outDir "pkgpub_smoke-0.1.0-dev.fnpkg"

& $fin init --dir $tmpDir --name pkgpub_smoke

& $fin pkg publish --manifest $manifest --src $sourceDir --out-dir $outDir
if (-not (Test-Path $artifact)) {
    Write-Error "Expected publish artifact: $artifact"
    exit 1
}

$content = Get-Content -Path $artifact -Raw
if ($content -notmatch '(?m)^FINPKG-1$') {
    Write-Error "Missing FINPKG-1 header."
    exit 1
}
if ($content -notmatch '(?m)^name=pkgpub_smoke$') {
    Write-Error "Missing expected package name metadata."
    exit 1
}
if ($content -notmatch '(?m)^version=0\.1\.0-dev$') {
    Write-Error "Missing expected package version metadata."
    exit 1
}
if ($content -notmatch '(?m)^file=fin\.toml$') {
    Write-Error "Expected fin.toml payload entry."
    exit 1
}
if ($content -notmatch '(?m)^file=fin\.lock$') {
    Write-Error "Expected fin.lock payload entry."
    exit 1
}
if ($content -notmatch '(?m)^file=src/main\.fn$') {
    Write-Error "Expected src/main.fn payload entry."
    exit 1
}

$firstHash = (Get-FileHash -Path $artifact -Algorithm SHA256).Hash
& $fin pkg publish --manifest $manifest --src $sourceDir --out-dir $outDir
$secondHash = (Get-FileHash -Path $artifact -Algorithm SHA256).Hash
if ($firstHash -ne $secondHash) {
    Write-Error "Expected deterministic artifact hash across repeated publish runs."
    exit 1
}

$dryRunDir = Join-Path $tmpDir "publish-dry"
$dryArtifact = Join-Path $dryRunDir "pkgpub_smoke-0.1.0-dev.fnpkg"
& $fin pkg publish --manifest $manifest --src $sourceDir --out-dir $dryRunDir --dry-run
if (Test-Path $dryArtifact) {
    Write-Error "Dry-run should not write artifact."
    exit 1
}

$failed = $false
try {
    & $fin pkg publish --manifest $manifest --src (Join-Path $tmpDir "missing-src") --out-dir $outDir | Out-Null
}
catch {
    $failed = $true
}
if (-not $failed) {
    Write-Error "Expected pkg publish to fail when source directory is missing."
    exit 1
}

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "pkg publish integration check passed."

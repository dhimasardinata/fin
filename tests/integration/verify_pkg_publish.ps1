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

function Assert-Fails {
    param(
        [scriptblock]$Action,
        [string]$Label
    )

    $failed = $false
    try {
        & $Action
    }
    catch {
        $failed = $true
    }

    if (-not $failed) {
        Write-Error ("Expected failure: {0}" -f $Label)
        exit 1
    }
}

& $fin init --dir $tmpDir --name pkgpub_smoke
Set-Content -Path (Join-Path $sourceDir "Main.fn") -Value @"
fn main() {
  exit(5)
}
"@

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
if ($content -cnotmatch '(?m)^file=src/Main\.fn$') {
    Write-Error "Expected case-distinct src/Main.fn payload entry."
    exit 1
}
if ($content -cnotmatch '(?m)^file=src/main\.fn$') {
    Write-Error "Expected lowercase src/main.fn payload entry."
    exit 1
}
$mainUpperIndex = $content.IndexOf("file=src/Main.fn")
$mainLowerIndex = $content.IndexOf("file=src/main.fn")
if (-not ($mainUpperIndex -lt $mainLowerIndex)) {
    Write-Error "Expected ordinal payload path order (src/Main.fn before src/main.fn)."
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

Assert-Fails -Action {
    & $fin pkg publish --manifest $manifest --src (Join-Path $tmpDir "missing-src") --out-dir $outDir | Out-Null
} -Label "missing source directory"

$validManifestContent = Get-Content -Path $manifest -Raw
$invalidManifestContent = $validManifestContent -replace 'external_toolchain_forbidden = true', 'external_toolchain_forbidden = false'
Set-Content -Path $manifest -Value $invalidManifestContent -NoNewline

Assert-Fails -Action {
    & $fin pkg publish --manifest $manifest --src $sourceDir --out-dir (Join-Path $tmpDir "publish-invalid") | Out-Null
} -Label "invalid manifest policy"

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "pkg publish integration check passed."

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "pkg-smoke-"
$tmpDir = $tmpState.TmpDir
$manifest = Join-Path $tmpDir "fin.toml"
$lock = Join-Path $tmpDir "fin.lock"

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

# Case-distinct dependency names should not be folded together.
& $fin pkg add Serde --version 4.0.0 --manifest $manifest
$content = Get-Content -Path $manifest -Raw
if ($content -cnotmatch '(?m)^Serde\s*=\s*"4\.0\.0"\s*$') {
    Write-Error "Expected case-distinct Serde dependency with version 4.0.0."
    exit 1
}
if ($content -cnotmatch '(?m)^serde\s*=\s*"3\.0\.0"\s*$') {
    Write-Error "Expected lowercase serde dependency to remain after adding Serde."
    exit 1
}
$manifestSerdeUpperIndex = $content.IndexOf('Serde = "4.0.0"')
$manifestHttpIndex = $content.IndexOf('http = "2.0.0"')
$manifestSerdeLowerIndex = $content.IndexOf('serde = "3.0.0"')
if (-not ($manifestSerdeUpperIndex -lt $manifestHttpIndex -and $manifestHttpIndex -lt $manifestSerdeLowerIndex)) {
    Write-Error "Expected ordinal dependency order in manifest (Serde before http before serde)."
    exit 1
}
$lockContent = Get-Content -Path $lock -Raw
if ($lockContent -cnotmatch '(?m)^\s*\{\s*name\s*=\s*"Serde",\s*version\s*=\s*"4\.0\.0"\s*\}\s*,?\s*$') {
    Write-Error "Expected case-distinct Serde dependency in fin.lock."
    exit 1
}
if ($lockContent -cnotmatch '(?m)^\s*\{\s*name\s*=\s*"serde",\s*version\s*=\s*"3\.0\.0"\s*\}\s*,?\s*$') {
    Write-Error "Expected lowercase serde dependency to remain in fin.lock."
    exit 1
}
$serdeUpperIndex = $lockContent.IndexOf('{ name = "Serde", version = "4.0.0" }')
$httpIndex = $lockContent.IndexOf('{ name = "http", version = "2.0.0" }')
$serdeLowerIndex = $lockContent.IndexOf('{ name = "serde", version = "3.0.0" }')
if ($serdeUpperIndex -lt 0 -or $httpIndex -lt 0 -or $serdeLowerIndex -lt 0) {
    Write-Error "Expected Serde, http, and serde entries in fin.lock."
    exit 1
}
if (-not ($serdeUpperIndex -lt $httpIndex -and $httpIndex -lt $serdeLowerIndex)) {
    Write-Error "Expected ordinal dependency order in fin.lock (Serde before http before serde)."
    exit 1
}

# Invalid package name should fail.
Assert-Fails -Action { & $fin pkg add "bad.name" --manifest $manifest | Out-Null } -Label "invalid package name"

# Invalid manifest policy should fail before mutation.
$validManifestContent = Get-Content -Path $manifest -Raw
$invalidManifestContent = $validManifestContent -replace 'external_toolchain_forbidden = true', 'external_toolchain_forbidden = false'
Set-Content -Path $manifest -Value $invalidManifestContent -NoNewline
$hashBeforeInvalidAdd = (Get-FileHash -Path $manifest -Algorithm SHA256).Hash
Assert-Fails -Action { & $fin pkg add blocked --version 1.0.0 --manifest $manifest | Out-Null } -Label "invalid manifest policy"
$hashAfterInvalidAdd = (Get-FileHash -Path $manifest -Algorithm SHA256).Hash
if ($hashBeforeInvalidAdd -ne $hashAfterInvalidAdd) {
    Write-Error "pkg add mutated manifest after policy failure."
    exit 1
}

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "pkg integration check passed."

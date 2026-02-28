Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "doc-smoke-"
$tmpDir = $tmpState.TmpDir
$source = Join-Path $tmpDir "main.fn"
$out = Join-Path $tmpDir "main.md"

Set-Content -Path $source -Value "fn main(){ exit(9); }"

& $fin doc --src $source --out $out

if (-not (Test-Path $out)) {
    Write-Error "Expected doc output file was not created."
    exit 1
}

$content = Get-Content -Path $out -Raw
if ($content -notmatch 'stage0 exit code: 9') {
    Write-Error "Generated doc did not include expected exit code."
    exit 1
}
if ($content -notmatch '### fn main\(\)') {
    Write-Error "Generated doc did not include function signature section."
    exit 1
}

$stdout = (& $fin doc --src $source --stdout | Out-String)
if ($stdout -notmatch 'Stage0 Source Documentation') {
    Write-Error "--stdout did not include document header."
    exit 1
}
if ($stdout -notmatch 'stage0 exit code: 9') {
    Write-Error "--stdout did not include expected exit code."
    exit 1
}

$failed = $false
try {
    & $fin doc --src $source --stdout --out $out | Out-Null
}
catch {
    $failed = $true
}
if (-not $failed) {
    Write-Error "Expected doc command to reject --stdout with --out."
    exit 1
}

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "doc integration check passed."

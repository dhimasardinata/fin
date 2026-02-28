Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "fmt-smoke-"
$tmpDir = $tmpState.TmpDir
$target = Join-Path $tmpDir "main.fn"

Set-Content -Path $target -Value "fn    main( ) {   exit( 7 ) ; }"

& $fin fmt --src $target

function Normalize-Text {
    param([string]$Text)
    return (($Text -replace "`r`n", "`n") -replace "`r", "`n")
}

$expected = "fn main() {`n  exit(7)`n}`n"
$formatted = Get-Content -Path $target -Raw
if ((Normalize-Text $formatted) -ne (Normalize-Text $expected)) {
    Write-Error "Formatter output did not match expected canonical source."
    exit 1
}

& $fin fmt --src $target --check

Set-Content -Path $target -Value "fn main(){exit(7);}"
$failed = $false
try {
    & $fin fmt --src $target --check | Out-Null
}
catch {
    $failed = $true
}

if (-not $failed) {
    Write-Error "Expected --check to fail on unformatted source."
    exit 1
}

$stdout = & $fin fmt --src $target --stdout
if ((Normalize-Text ($stdout | Out-String)) -notmatch [regex]::Escape("fn main() {`n  exit(7)`n}")) {
    Write-Error "--stdout did not return expected formatted output."
    exit 1
}

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "fmt integration check passed."

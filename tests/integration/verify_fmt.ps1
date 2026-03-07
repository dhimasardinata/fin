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

$multiTarget = Join-Path $tmpDir "multi.fn"
$multiSource = "fn helper() {`n  return 1;`n}`n`nfn main() {`n  exit(helper());`n}`n"
Set-Content -Path $multiTarget -Value $multiSource -NoNewline

& $fin fmt --src $multiTarget

$multiFormatted = Get-Content -Path $multiTarget -Raw
if ((Normalize-Text $multiFormatted) -ne (Normalize-Text $multiSource)) {
    Write-Error "Formatter must preserve multi-function stage0 sources until structured helper formatting lands."
    exit 1
}

$blockTarget = Join-Path $tmpDir "block.fn"
$blockSource = "fn main() {`n  var value = 160`n  {`n    let add = 7`n    value += add`n  }`n  exit(value)`n}`n"
Set-Content -Path $blockTarget -Value $blockSource -NoNewline

& $fin fmt --src $blockTarget

$blockFormatted = Get-Content -Path $blockTarget -Raw
if ((Normalize-Text $blockFormatted) -ne (Normalize-Text $blockSource)) {
    Write-Error "Formatter must preserve structured single-function block sources until block formatting lands."
    exit 1
}

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "fmt integration check passed."

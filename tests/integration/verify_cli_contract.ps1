Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$rootShim = Join-Path $repoRoot "fin.ps1"
$cmdShim = Join-Path $repoRoot "cmd/fin/fin.ps1"
$suite = Join-Path $repoRoot "tests/run_stage0_suite.ps1"
$cliDocs = Join-Path $repoRoot "docs/cli-contract.md"
$cmdDocs = Join-Path $repoRoot "cmd/fin/README.md"
$fip = Join-Path $repoRoot "fips/FIP-0015-unified-fin-cli-contract.md"

function Fail-CliContract {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Needle,
        [string]$Label
    )

    if (-not $Text.Contains($Needle)) {
        Fail-CliContract ("{0} missing: {1}" -f $Label, $Needle)
    }
}

$rootText = Get-Content -LiteralPath $rootShim -Raw
$cmdText = Get-Content -LiteralPath $cmdShim -Raw
$suiteText = Get-Content -LiteralPath $suite -Raw
$cliDocText = Get-Content -LiteralPath $cliDocs -Raw
$cmdDocText = Get-Content -LiteralPath $cmdDocs -Raw
$fipText = Get-Content -LiteralPath $fip -Raw

Assert-Contains -Text $rootText -Needle "[Parameter(Position = 1, ValueFromRemainingArguments = `$true)]" -Label "root fin shim"
Assert-Contains -Text $cmdText -Needle "[Parameter(Position = 1, ValueFromRemainingArguments = `$true)]" -Label "cmd fin shim"

foreach ($flag in @("--quick", "--no-doctor", "--no-run")) {
    Assert-Contains -Text $cmdText -Needle $flag -Label "cmd fin test options"
    Assert-Contains -Text $cliDocText -Needle $flag -Label "CLI contract docs"
    Assert-Contains -Text $cmdDocText -Needle $flag -Label "cmd fin README"
    Assert-Contains -Text $fipText -Needle $flag -Label "FIP-0015"
}

Assert-Contains -Text $cmdText -Needle '$suiteArgs = @{}' -Label "test option forwarding"
Assert-Contains -Text $cmdText -Needle '$suiteArgs["Quick"] = $true' -Label "quick forwarding"
Assert-Contains -Text $cmdText -Needle '$suiteArgs["SkipDoctor"] = $true' -Label "no-doctor forwarding"
Assert-Contains -Text $cmdText -Needle '$suiteArgs["SkipRun"] = $true' -Label "no-run forwarding"
Assert-Contains -Text $cmdText -Needle '& $suite @suiteArgs' -Label "suite hashtable splat"

foreach ($needle in @('[switch]$Quick', '[switch]$SkipDoctor', '[switch]$SkipRun', 'if (-not $SkipDoctor)', 'if (-not $SkipRun)')) {
    Assert-Contains -Text $suiteText -Needle $needle -Label "stage0 test suite options"
}

Write-Host "CLI contract integration check passed."

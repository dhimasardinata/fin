Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$charter = Join-Path $repoRoot "docs/charter.md"
$readme = Join-Path $repoRoot "README.md"
$spec = Join-Path $repoRoot "SPEC.md"
$governance = Join-Path $repoRoot "GOVERNANCE.md"
$fip = Join-Path $repoRoot "fips/FIP-0001-language-charter-philosophy.md"
$index = Join-Path $repoRoot "fips/INDEX.md"
$suite = Join-Path $repoRoot "tests/run_stage0_suite.ps1"

function Fail-CharterPolicy {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

$charterText = Get-Content -LiteralPath $charter -Raw
$readmeText = Get-Content -LiteralPath $readme -Raw
$specText = Get-Content -LiteralPath $spec -Raw
$governanceText = Get-Content -LiteralPath $governance -Raw
$fipText = Get-Content -LiteralPath $fip -Raw
$indexText = Get-Content -LiteralPath $index -Raw
$suiteText = Get-Content -LiteralPath $suite -Raw

if ($fipText -notmatch "(?m)^- status: Implemented$") {
    Fail-CharterPolicy "FIP-0001 must be Implemented once the charter gate exists"
}

if ($indexText -notmatch [regex]::Escape("| FIP-0001 | Language Charter and Philosophy | Implemented |")) {
    Fail-CharterPolicy "FIP index must mark FIP-0001 Implemented"
}

foreach ($section in @("## Goals", "## Non-Goals", "## Product Philosophy", "## Non-Negotiable Constraints")) {
    if ($charterText -notmatch [regex]::Escape($section)) {
        Fail-CharterPolicy ("charter missing section: {0}" -f $section)
    }
}

foreach ($phrase in @(
    "FIP-0001",
    "full-independent native programming language",
    "zero-cost",
    "inference-first safety",
    "deterministic and reproducible",
    "external compiler, assembler, and linker",
    "audited seed artifact",
    "no-libc"
)) {
    if ($charterText -notmatch [regex]::Escape($phrase)) {
        Fail-CharterPolicy ("charter missing phrase: {0}" -f $phrase)
    }
}

foreach ($text in @($readmeText, $specText, $governanceText)) {
    if ($text -notmatch [regex]::Escape("FIP-0001")) {
        Fail-CharterPolicy "README, SPEC, and GOVERNANCE must reference FIP-0001"
    }
    if ($text -notmatch [regex]::Escape("docs/charter.md")) {
        Fail-CharterPolicy "README, SPEC, and GOVERNANCE must reference docs/charter.md"
    }
}

foreach ($path in @("docs/charter.md", "README.md", "SPEC.md", "GOVERNANCE.md", "tests/reproducibility/verify_charter_policy_gate.ps1", "tests/run_stage0_suite.ps1")) {
    if ($fipText -notmatch [regex]::Escape($path)) {
        Fail-CharterPolicy ("FIP-0001 implementation list missing: {0}" -f $path)
    }
}

if ($suiteText -notmatch [regex]::Escape("tests/reproducibility/verify_charter_policy_gate.ps1")) {
    Fail-CharterPolicy "stage0 suite must call the charter policy verifier"
}

Write-Host "charter policy check passed."

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$compat = Join-Path $repoRoot "COMPATIBILITY.md"
$governance = Join-Path $repoRoot "GOVERNANCE.md"
$release = Join-Path $repoRoot "docs/release-provenance.md"
$template = Join-Path $repoRoot ".github/PULL_REQUEST_TEMPLATE.md"
$fip = Join-Path $repoRoot "fips/FIP-0019-compatibility-editions-policy.md"

function Fail-CompatibilityPolicy {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

$compatText = Get-Content -LiteralPath $compat -Raw
$governanceText = Get-Content -LiteralPath $governance -Raw
$releaseText = Get-Content -LiteralPath $release -Raw
$releaseTextNormalized = ($releaseText -replace "\s+", " ").Trim()
$templateText = Get-Content -LiteralPath $template -Raw
$fipText = Get-Content -LiteralPath $fip -Raw

foreach ($section in @("## Versioning", "## Stability Buckets", "## Breaking Change Rules", "## Edition Policy", "## Reproducibility Requirement")) {
    if ($compatText -notmatch [regex]::Escape($section)) {
        Fail-CompatibilityPolicy ("COMPATIBILITY.md missing section: {0}" -f $section)
    }
}

foreach ($phrase in @("FIP-0019", "semantic versioning", "Stable", "Experimental", "Internal", "migration notes", "compatibility tests", "release notes")) {
    if ($compatText -notmatch [regex]::Escape($phrase)) {
        Fail-CompatibilityPolicy ("COMPATIBILITY.md missing policy phrase: {0}" -f $phrase)
    }
}

foreach ($phrase in @('Breaking changes additionally require compatibility analysis per `COMPATIBILITY.md`.', 'Releases are tagged from `main`')) {
    if ($governanceText -notmatch [regex]::Escape($phrase)) {
        Fail-CompatibilityPolicy ("GOVERNANCE.md missing compatibility governance phrase: {0}" -f $phrase)
    }
}

foreach ($phrase in @('Compatibility notes derived from `COMPATIBILITY.md`', "breaking syntax, semantic, ABI", "package contract change", "link the governing FIP")) {
    if ($releaseTextNormalized -notmatch [regex]::Escape($phrase)) {
        Fail-CompatibilityPolicy ("release provenance doc missing compatibility phrase: {0}" -f $phrase)
    }
}

foreach ($phrase in @("I documented compatibility impact", "Linked Proposal", "FIP:")) {
    if ($templateText -notmatch [regex]::Escape($phrase)) {
        Fail-CompatibilityPolicy ("pull request template missing compatibility/FIP phrase: {0}" -f $phrase)
    }
}

if ($fipText -notmatch "(?m)^- status: Implemented$") {
    Fail-CompatibilityPolicy "FIP-0019 must be Implemented once compatibility policy gate exists"
}

foreach ($path in @("COMPATIBILITY.md", "GOVERNANCE.md", "docs/release-provenance.md", ".github/PULL_REQUEST_TEMPLATE.md", "tests/reproducibility/verify_compatibility_policy.ps1", "tests/run_stage0_suite.ps1")) {
    if ($fipText -notmatch [regex]::Escape($path)) {
        Fail-CompatibilityPolicy ("FIP-0019 implementation list missing: {0}" -f $path)
    }
}

Write-Host "Compatibility policy check passed."

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$stdReadme = Join-Path $repoRoot "std/README.md"
$fip = Join-Path $repoRoot "fips/FIP-0017-lean-stdlib-v0-no-libc.md"

function Fail-StdlibContract {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

$stdText = Get-Content -LiteralPath $stdReadme -Raw
$fipText = Get-Content -LiteralPath $fip -Raw

foreach ($section in @("## Stage0 API Plan", "## No-libc Contract")) {
    if ($stdText -notmatch [regex]::Escape($section)) {
        Fail-StdlibContract ("std README missing section: {0}" -f $section)
    }
}

foreach ($module in @("core", "result", "sys", "io", "time", "alloc", "thread", "channel")) {
    $modulePattern = "(?m)^- ``{0}``: " -f [regex]::Escape($module)
    if ($stdText -notmatch $modulePattern) {
        Fail-StdlibContract ("std README missing required module entry: {0}" -f $module)
    }
}

foreach ($phrase in @("No libc assumptions are allowed", "Fin runtime shims", "FIP-0009", "FIP-0012")) {
    if ($stdText -notmatch [regex]::Escape($phrase)) {
        Fail-StdlibContract ("std README missing no-libc contract phrase: {0}" -f $phrase)
    }
}

foreach ($banned in @("printf", "malloc", "pthread", "msvcrt", "glibc")) {
    if ($stdText -match ("(?i)\b{0}\b" -f [regex]::Escape($banned))) {
        Fail-StdlibContract ("std README contains host C runtime dependency marker: {0}" -f $banned)
    }
}

if ($fipText -notmatch "(?m)^- status: (InProgress|Implemented)$") {
    Fail-StdlibContract "FIP-0017 must be InProgress or Implemented once stdlib contract gate exists"
}

foreach ($path in @("std/README.md", "tests/conformance/verify_stdlib_contract.ps1", "tests/run_stage0_suite.ps1")) {
    if ($fipText -notmatch [regex]::Escape($path)) {
        Fail-StdlibContract ("FIP-0017 implementation list missing: {0}" -f $path)
    }
}

Write-Host "Stdlib contract check passed."

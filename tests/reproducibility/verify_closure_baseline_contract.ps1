param(
    [string]$Baseline = "",
    [string]$Fip = "",
    [string]$Suite = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

if ([string]::IsNullOrWhiteSpace($Baseline)) {
    $Baseline = Join-Path $repoRoot "seed/stage0-closure-baseline.txt"
}
elseif (-not [System.IO.Path]::IsPathRooted($Baseline)) {
    $Baseline = Join-Path $repoRoot $Baseline
}

if ([string]::IsNullOrWhiteSpace($Fip)) {
    $Fip = Join-Path $repoRoot "fips/FIP-0011-self-hosting-closure-criteria.md"
}
elseif (-not [System.IO.Path]::IsPathRooted($Fip)) {
    $Fip = Join-Path $repoRoot $Fip
}

if ([string]::IsNullOrWhiteSpace($Suite)) {
    $Suite = Join-Path $repoRoot "tests/run_stage0_suite.ps1"
}
elseif (-not [System.IO.Path]::IsPathRooted($Suite)) {
    $Suite = Join-Path $repoRoot $Suite
}

function Fail-ClosureBaseline {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

function Get-TextHashHex {
    param([string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)
        return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
    }
    finally {
        $sha.Dispose()
    }
}

function Assert-Sha256OrUnset {
    param(
        [string]$Value,
        [string]$Label,
        [switch]$AllowUnset
    )

    if ($AllowUnset -and $Value -ceq "UNSET") {
        return
    }

    if ($Value -cnotmatch "^[0-9a-f]{64}$") {
        Fail-ClosureBaseline ("{0} must be a lowercase SHA256 hex value" -f $Label)
    }
}

$requiredKeys = @(
    "closure_mode",
    "source",
    "seed_declared_sha256",
    "seed_snapshot_sha256",
    "toolchain_snapshot_sha256",
    "closure_hash",
    "linux_direct_sha256",
    "linux_finobj_sha256",
    "windows_direct_sha256",
    "windows_finobj_sha256",
    "linux_pipeline_parity",
    "windows_pipeline_parity",
    "closure_equal"
)

$map = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
$orderedKeys = [System.Collections.Generic.List[string]]::new()
foreach ($line in Get-Content -LiteralPath $Baseline) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) {
        continue
    }

    if ($trimmed -cnotmatch "^([A-Za-z0-9_]+)=(.*)$") {
        Fail-ClosureBaseline ("invalid baseline line: {0}" -f $trimmed)
    }

    $key = [string]$Matches[1]
    if ($map.ContainsKey($key)) {
        Fail-ClosureBaseline ("duplicate baseline key: {0}" -f $key)
    }

    $map[$key] = ([string]$Matches[2]).Trim()
    $orderedKeys.Add($key)
}

$order = ($orderedKeys.ToArray() -join ",")
$requiredOrder = ($requiredKeys -join ",")
if ($order -cne $requiredOrder) {
    Fail-ClosureBaseline ("baseline key order mismatch: expected={0} actual={1}" -f $requiredOrder, $order)
}

foreach ($key in $requiredKeys) {
    if (-not $map.ContainsKey($key)) {
        Fail-ClosureBaseline ("baseline missing key: {0}" -f $key)
    }
}

foreach ($key in ($map.Keys | Sort-Object)) {
    if ($requiredKeys -cnotcontains $key) {
        Fail-ClosureBaseline ("baseline has unexpected key: {0}" -f $key)
    }
}

if ($map["closure_mode"] -cne "stage0-proxy") {
    Fail-ClosureBaseline "closure_mode must be stage0-proxy"
}

$source = $map["source"]
if ([System.IO.Path]::IsPathRooted($source) -or $source -match '(^|[\\/])\.\.([\\/]|$)') {
    Fail-ClosureBaseline "source must be a relative repo path without parent traversal"
}

$sourcePath = Join-Path $repoRoot $source
if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
    Fail-ClosureBaseline ("closure source path is missing: {0}" -f $map["source"])
}

Assert-Sha256OrUnset -Value $map["seed_declared_sha256"] -Label "seed_declared_sha256" -AllowUnset
foreach ($key in @("seed_snapshot_sha256", "toolchain_snapshot_sha256", "closure_hash", "linux_direct_sha256", "linux_finobj_sha256", "windows_direct_sha256", "windows_finobj_sha256")) {
    Assert-Sha256OrUnset -Value $map[$key] -Label $key
}

if ($map["linux_direct_sha256"] -cne $map["linux_finobj_sha256"]) {
    Fail-ClosureBaseline "linux direct/finobj hashes must match"
}

if ($map["windows_direct_sha256"] -cne $map["windows_finobj_sha256"]) {
    Fail-ClosureBaseline "windows direct/finobj hashes must match"
}

foreach ($key in @("linux_pipeline_parity", "windows_pipeline_parity", "closure_equal")) {
    if ($map[$key] -cne "true") {
        Fail-ClosureBaseline ("{0} must be true" -f $key)
    }
}

$matrixText = @(
    ("linux_direct={0}" -f $map["linux_direct_sha256"]),
    ("linux_finobj={0}" -f $map["linux_finobj_sha256"]),
    ("windows_direct={0}" -f $map["windows_direct_sha256"]),
    ("windows_finobj={0}" -f $map["windows_finobj_sha256"])
) -join "`n"
$derivedClosureHash = Get-TextHashHex -Text ($matrixText + "`n")
if ($map["closure_hash"] -cne $derivedClosureHash) {
    Fail-ClosureBaseline ("closure_hash derivation mismatch: expected={0} actual={1}" -f $derivedClosureHash, $map["closure_hash"])
}

$fipText = Get-Content -LiteralPath $Fip -Raw
$fipImplementationMatch = [regex]::Match($fipText, "(?ms)^- implementation:\s*(?<body>.*?)(?=^\- acceptance:)")
if (-not $fipImplementationMatch.Success) {
    Fail-ClosureBaseline "FIP-0011 must have an implementation block"
}

if ($fipImplementationMatch.Groups["body"].Value -cnotmatch [regex]::Escape("tests/reproducibility/verify_closure_baseline_contract.ps1")) {
    Fail-ClosureBaseline "FIP-0011 implementation list must include closure baseline verifier"
}

$suiteText = Get-Content -LiteralPath $Suite -Raw
if ($suiteText -cnotmatch [regex]::Escape("tests/reproducibility/verify_closure_baseline_contract.ps1")) {
    Fail-ClosureBaseline "stage0 suite must call the closure baseline verifier"
}

$baselineVerifierCall = '& $verifyClosureBaselineContract'
$closureVerifierCall = '& $verifyClosure -VerifyBaseline'
$baselineCallIndex = $suiteText.IndexOf($baselineVerifierCall, [System.StringComparison]::Ordinal)
$closureCallIndex = $suiteText.IndexOf($closureVerifierCall, [System.StringComparison]::Ordinal)

if ($baselineCallIndex -lt 0) {
    Fail-ClosureBaseline "stage0 suite must invoke the closure baseline verifier"
}

if ($closureCallIndex -lt 0) {
    Fail-ClosureBaseline "stage0 suite must invoke closure baseline verification"
}

if ($baselineCallIndex -gt $closureCallIndex) {
    Fail-ClosureBaseline "stage0 suite must run closure baseline contract check before closure verification"
}

Write-Host "closure baseline contract check passed."

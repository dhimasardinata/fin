param(
    [string]$Source = "tests/conformance/fixtures/main_exit_var_assign.fn",
    [string]$OutDir = "artifacts/closure",
    [string]$Witness = "",
    [switch]$RequireSeedSet,
    [string]$Baseline = "seed/stage0-closure-baseline.txt",
    [switch]$VerifyBaseline
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$seedCheck = Join-Path $repoRoot "ci/verify_seed_hash.ps1"

function Normalize-Text {
    param([string]$Text)
    return (($Text -replace "`r`n", "`n") -replace "`r", "`n")
}

function Get-TextHashHex {
    param([string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-FileHashHex {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-NormalizedFileHashHex {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Missing file for normalized hash: $Path"
    }
    $raw = Get-Content -Path $Path -Raw
    return Get-TextHashHex -Text (Normalize-Text -Text $raw)
}

function Get-RelativePathNormalized {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    $baseDir = [System.IO.Path]::GetFullPath($BasePath)
    $full = [System.IO.Path]::GetFullPath($FullPath)

    Push-Location -Path $baseDir
    try {
        $relative = Resolve-Path -LiteralPath $full -Relative
    }
    finally {
        Pop-Location
    }

    if ($relative.StartsWith(".\")) {
        $relative = $relative.Substring(2)
    }
    elseif ($relative.StartsWith("./")) {
        $relative = $relative.Substring(2)
    }
    return $relative.Replace("\", "/")
}

function Get-Snapshot {
    param([string[]]$RelativePaths)

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($rel in $RelativePaths) {
        $full = Join-Path $repoRoot $rel
        if (-not (Test-Path $full)) {
            throw "Missing snapshot file: $full"
        }
        $lines.Add(("{0} {1}" -f $rel, (Get-NormalizedFileHashHex -Path $full)))
    }

    $ordered = @($lines | Sort-Object)
    $payload = ($ordered -join "`n") + "`n"
    return @{
        Hash = Get-TextHashHex -Text $payload
        Lines = $ordered
    }
}

function Parse-KeyValueFile {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        throw "Missing key-value file: $Path"
    }

    $map = @{}
    foreach ($line in ([regex]::Split((Get-Content -Path $Path -Raw), "`r?`n"))) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("#")) { continue }
        if ($trimmed -notmatch '^([A-Za-z0-9_.-]+)\s*=\s*(.+)$') {
            throw "Invalid key-value line in ${Path}: $trimmed"
        }
        $map[$Matches[1]] = $Matches[2].Trim()
    }
    return $map
}

if ($RequireSeedSet) {
    & $seedCheck -RequireSet
}
else {
    & $seedCheck
}

$sourceForFin = $Source
if (-not [System.IO.Path]::IsPathRooted($sourceForFin)) {
    $sourceForFin = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $sourceForFin))
}
$sourceLabel = Get-RelativePathNormalized -BasePath $repoRoot -FullPath $sourceForFin

$outDirFull = if ([System.IO.Path]::IsPathRooted($OutDir)) {
    [System.IO.Path]::GetFullPath($OutDir)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutDir))
}

if (-not (Test-Path $outDirFull)) {
    New-Item -ItemType Directory -Path $outDirFull -Force | Out-Null
}

$witnessPath = $Witness
if ([string]::IsNullOrWhiteSpace($witnessPath)) {
    $witnessPath = Join-Path $outDirFull "stage0-closure-witness.txt"
}
elseif (-not [System.IO.Path]::IsPathRooted($witnessPath)) {
    $witnessPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $witnessPath))
}

$witnessDir = Split-Path -Parent $witnessPath
if ($witnessDir -and -not (Test-Path $witnessDir)) {
    New-Item -ItemType Directory -Path $witnessDir -Force | Out-Null
}

function Invoke-ClosureCase {
    param(
        [string]$CaseId,
        [string]$Target,
        [string]$Pipeline
    )

    $isWindowsTarget = ($Target -eq "x86_64-windows-pe")
    $ext = if ($isWindowsTarget) { ".exe" } else { "" }
    $gen1 = Join-Path $outDirFull ("gen1-{0}{1}" -f $CaseId, $ext)
    $gen2 = Join-Path $outDirFull ("gen2-{0}{1}" -f $CaseId, $ext)

    & $fin build --src $sourceForFin --out $gen1 --target $Target --pipeline $Pipeline
    & $fin build --src $sourceForFin --out $gen2 --target $Target --pipeline $Pipeline

    $gen1Hash = Get-FileHashHex -Path $gen1
    $gen2Hash = Get-FileHashHex -Path $gen2
    if ($gen1Hash -ne $gen2Hash) {
        Write-Error ("Stage0 closure proxy mismatch ({0}): gen1={1}, gen2={2}" -f $CaseId, $gen1Hash, $gen2Hash)
        exit 1
    }

    return @{
        CaseId = $CaseId
        Target = $Target
        Pipeline = $Pipeline
        Generation1Hash = $gen1Hash
        Generation2Hash = $gen2Hash
    }
}

# Stage0 proxy closure:
# each case must be deterministic across two generations, and direct/finobj parity must hold per target.
$linuxDirect = Invoke-ClosureCase -CaseId "linux-direct" -Target "x86_64-linux-elf" -Pipeline "direct"
$linuxFinobj = Invoke-ClosureCase -CaseId "linux-finobj" -Target "x86_64-linux-elf" -Pipeline "finobj"
$windowsDirect = Invoke-ClosureCase -CaseId "windows-direct" -Target "x86_64-windows-pe" -Pipeline "direct"
$windowsFinobj = Invoke-ClosureCase -CaseId "windows-finobj" -Target "x86_64-windows-pe" -Pipeline "finobj"

$linuxParity = ($linuxDirect.Generation1Hash -eq $linuxFinobj.Generation1Hash)
if (-not $linuxParity) {
    Write-Error ("Stage0 closure parity mismatch (linux): direct={0}, finobj={1}" -f $linuxDirect.Generation1Hash, $linuxFinobj.Generation1Hash)
    exit 1
}

$windowsParity = ($windowsDirect.Generation1Hash -eq $windowsFinobj.Generation1Hash)
if (-not $windowsParity) {
    Write-Error ("Stage0 closure parity mismatch (windows): direct={0}, finobj={1}" -f $windowsDirect.Generation1Hash, $windowsFinobj.Generation1Hash)
    exit 1
}

$closureMatrixLines = [System.Collections.Generic.List[string]]::new()
$closureMatrixLines.Add(("linux_direct={0}" -f $linuxDirect.Generation1Hash))
$closureMatrixLines.Add(("linux_finobj={0}" -f $linuxFinobj.Generation1Hash))
$closureMatrixLines.Add(("windows_direct={0}" -f $windowsDirect.Generation1Hash))
$closureMatrixLines.Add(("windows_finobj={0}" -f $windowsFinobj.Generation1Hash))
$closureHash = Get-TextHashHex -Text ((($closureMatrixLines.ToArray() -join "`n") + "`n"))

$toolchainSnapshot = Get-Snapshot -RelativePaths @(
    "cmd/fin/fin.ps1",
    "compiler/finc/stage0/build_stage0.ps1",
    "compiler/finc/stage0/parse_main_exit.ps1",
    "compiler/finc/stage0/emit_elf_exit0.ps1",
    "compiler/finc/stage0/emit_pe_exit0.ps1",
    "compiler/finobj/stage0/write_finobj_exit.ps1",
    "compiler/finobj/stage0/read_finobj_exit.ps1",
    "compiler/finld/stage0/link_finobj_to_elf.ps1"
)

$seedSnapshot = Get-Snapshot -RelativePaths @(
    "seed/manifest.toml",
    "seed/SHA256SUMS"
)

$seedManifestRaw = Get-Content -Path (Join-Path $repoRoot "seed/manifest.toml") -Raw
$declaredSeed = "UNSET"
if ($seedManifestRaw -match 'sha256\s*=\s*"([^"]+)"') {
    $declaredSeed = $Matches[1]
}

$witnessLines = [System.Collections.Generic.List[string]]::new()
$witnessLines.Add("closure_mode=stage0-proxy")
$witnessLines.Add(("source={0}" -f $sourceLabel))
$witnessLines.Add(("seed_declared_sha256={0}" -f $declaredSeed))
$witnessLines.Add(("seed_snapshot_sha256={0}" -f $seedSnapshot.Hash))
$witnessLines.Add(("toolchain_snapshot_sha256={0}" -f $toolchainSnapshot.Hash))
$witnessLines.Add(("closure_hash={0}" -f $closureHash))
$witnessLines.Add(("linux_direct_sha256={0}" -f $linuxDirect.Generation1Hash))
$witnessLines.Add(("linux_finobj_sha256={0}" -f $linuxFinobj.Generation1Hash))
$witnessLines.Add(("windows_direct_sha256={0}" -f $windowsDirect.Generation1Hash))
$witnessLines.Add(("windows_finobj_sha256={0}" -f $windowsFinobj.Generation1Hash))
$witnessLines.Add(("linux_pipeline_parity={0}" -f $linuxParity.ToString().ToLowerInvariant()))
$witnessLines.Add(("windows_pipeline_parity={0}" -f $windowsParity.ToString().ToLowerInvariant()))
$witnessLines.Add("closure_equal=true")

$witnessContent = ($witnessLines.ToArray() -join "`n") + "`n"
Set-Content -Path $witnessPath -Value $witnessContent -NoNewline

if ($VerifyBaseline) {
    $baselinePath = $Baseline
    if (-not [System.IO.Path]::IsPathRooted($baselinePath)) {
        $baselinePath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $baselinePath))
    }

    $expected = Parse-KeyValueFile -Path $baselinePath
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

    $actual = @{
        closure_mode = "stage0-proxy"
        source = $sourceLabel
        seed_declared_sha256 = $declaredSeed
        seed_snapshot_sha256 = $seedSnapshot.Hash
        toolchain_snapshot_sha256 = $toolchainSnapshot.Hash
        closure_hash = $closureHash
        linux_direct_sha256 = $linuxDirect.Generation1Hash
        linux_finobj_sha256 = $linuxFinobj.Generation1Hash
        windows_direct_sha256 = $windowsDirect.Generation1Hash
        windows_finobj_sha256 = $windowsFinobj.Generation1Hash
        linux_pipeline_parity = "true"
        windows_pipeline_parity = "true"
        closure_equal = "true"
    }

    $missing = @()
    $mismatch = @()
    $unexpected = @()
    foreach ($k in $requiredKeys) {
        if (-not $expected.ContainsKey($k)) {
            $missing += $k
            continue
        }
        if ([string]$expected[$k] -ne [string]$actual[$k]) {
            $mismatch += ("{0}: expected={1} actual={2}" -f $k, $expected[$k], $actual[$k])
        }
    }

    foreach ($k in ($expected.Keys | Sort-Object)) {
        if ($requiredKeys -notcontains $k) {
            $unexpected += $k
        }
    }

    if ($missing.Count -gt 0 -or $mismatch.Count -gt 0 -or $unexpected.Count -gt 0) {
        $issues = @()
        if ($missing.Count -gt 0) {
            $issues += ("missing_keys={0}" -f ($missing -join ","))
        }
        if ($mismatch.Count -gt 0) {
            $issues += ("mismatch={0}" -f ($mismatch -join "; "))
        }
        if ($unexpected.Count -gt 0) {
            $issues += ("unexpected_keys={0}" -f ($unexpected -join ","))
        }
        Write-Error ("Closure baseline mismatch in {0}: {1}" -f $baselinePath, ($issues -join " | "))
        exit 1
    }

    Write-Host ("closure_baseline_verified={0}" -f $baselinePath)
}

Write-Host ("closure_mode=stage0-proxy")
Write-Host ("closure_hash={0}" -f $closureHash)
Write-Host ("witness={0}" -f $witnessPath)
Write-Host "stage0 closure check passed."

param(
    [string]$Source = "tests/conformance/fixtures/main_exit_var_assign.fn",
    [string]$OutDir = "artifacts/closure",
    [string]$Witness = "",
    [switch]$RequireSeedSet
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$seedCheck = Join-Path $repoRoot "ci/verify_seed_hash.ps1"

function Get-FileHashHex {
    param([string]$Path)
    return (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
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

function Get-Snapshot {
    param([string[]]$RelativePaths)

    $lines = [System.Collections.Generic.List[string]]::new()
    foreach ($rel in $RelativePaths) {
        $full = Join-Path $repoRoot $rel
        if (-not (Test-Path $full)) {
            throw "Missing snapshot file: $full"
        }
        $lines.Add(("{0} {1}" -f $rel, (Get-FileHashHex -Path $full)))
    }

    $ordered = @($lines | Sort-Object)
    $payload = ($ordered -join "`n") + "`n"
    return @{
        Hash = Get-TextHashHex -Text $payload
        Lines = $ordered
    }
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

$gen1 = Join-Path $outDirFull "gen1-main"
$gen2 = Join-Path $outDirFull "gen2-main"

# Stage0 proxy closure:
# generation 1 and generation 2 build outputs must be hash-identical for fixed inputs.
& $fin build --src $sourceForFin --out $gen1
& $fin build --src $sourceForFin --out $gen2

$gen1Hash = Get-FileHashHex -Path $gen1
$gen2Hash = Get-FileHashHex -Path $gen2
if ($gen1Hash -ne $gen2Hash) {
    Write-Error ("Stage0 closure proxy mismatch: gen1={0}, gen2={1}" -f $gen1Hash, $gen2Hash)
    exit 1
}

$toolchainSnapshot = Get-Snapshot -RelativePaths @(
    "cmd/fin/fin.ps1",
    "compiler/finc/stage0/build_stage0.ps1",
    "compiler/finc/stage0/parse_main_exit.ps1",
    "compiler/finc/stage0/emit_elf_exit0.ps1"
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
$witnessLines.Add(("source={0}" -f $sourceForFin))
$witnessLines.Add(("seed_declared_sha256={0}" -f $declaredSeed))
$witnessLines.Add(("seed_snapshot_sha256={0}" -f $seedSnapshot.Hash))
$witnessLines.Add(("toolchain_snapshot_sha256={0}" -f $toolchainSnapshot.Hash))
$witnessLines.Add(("generation1_output_sha256={0}" -f $gen1Hash))
$witnessLines.Add(("generation2_output_sha256={0}" -f $gen2Hash))
$witnessLines.Add("closure_equal=true")

$witnessContent = ($witnessLines.ToArray() -join "`n") + "`n"
Set-Content -Path $witnessPath -Value $witnessContent -NoNewline

Write-Host ("closure_mode=stage0-proxy")
Write-Host ("closure_hash={0}" -f $gen1Hash)
Write-Host ("witness={0}" -f $witnessPath)
Write-Host "stage0 closure check passed."

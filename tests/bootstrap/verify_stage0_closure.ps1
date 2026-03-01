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
    $orderedKeys = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ([regex]::Split((Get-Content -Path $Path -Raw), "`r?`n"))) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("#")) { continue }
        if ($trimmed -notmatch '^([A-Za-z0-9_.-]+)\s*=\s*(.+)$') {
            throw "Invalid key-value line in ${Path}: $trimmed"
        }
        $key = $Matches[1]
        if ($map.ContainsKey($key)) {
            throw "Duplicate key in ${Path}: $key"
        }
        $map[$key] = $Matches[2].Trim()
        $orderedKeys.Add($key)
    }
    return [pscustomobject]@{
        Map = $map
        OrderedKeys = $orderedKeys.ToArray()
    }
}

function Write-TextFileAtomic {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Value
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }

    $tempPath = Join-Path $dir (".tmp-{0}.txt" -f [Guid]::NewGuid().ToString("N"))
    try {
        Set-Content -Path $tempPath -Value $Value -NoNewline
        Move-Item -LiteralPath $tempPath -Destination $Path -Force
    }
    finally {
        if (Test-Path $tempPath) {
            Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Remove-ClosureWorkspaceDirectory {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [switch]$IgnoreFailure
    )

    if (-not (Test-Path $Path)) {
        return
    }

    $lastError = $null
    for ($attempt = 1; $attempt -le 8; $attempt++) {
        try {
            Remove-Item -Recurse -Force $Path -ErrorAction Stop
            return
        }
        catch {
            $lastError = $_
            if ($attempt -lt 8) {
                Start-Sleep -Milliseconds 150
            }
        }
    }

    if ($IgnoreFailure) {
        Write-Warning ("Failed to remove closure workspace after retries: {0}" -f $Path)
        return
    }

    if ($null -ne $lastError) {
        throw $lastError
    }
}

function Get-ClosureWorkspaceProcessStartUtc {
    param(
        [Parameter(Mandatory = $true)]
        [int]$OwnerPid
    )

    $proc = Get-Process -Id $OwnerPid -ErrorAction Stop
    return $proc.StartTime.ToUniversalTime()
}

function Set-ClosureWorkspaceOwnerMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [string]$WorkspaceDir,
        [Parameter(Mandatory = $true)]
        [int]$OwnerPid,
        [Parameter(Mandatory = $true)]
        [datetime]$OwnerStartUtc
    )

    $metadataPath = Join-Path $WorkspaceDir ".fin-closure-owner.json"
    $payload = [ordered]@{
        pid = [int]$OwnerPid
        start_utc = $OwnerStartUtc.ToUniversalTime().ToString("o")
    } | ConvertTo-Json -Compress
    Set-Content -Path $metadataPath -Value $payload -NoNewline
}

function Test-ClosureWorkspacePidActive {
    param(
        [Parameter(Mandatory = $true)]
        [int]$OwnerPid
    )

    try {
        return $null -ne (Get-Process -Id $OwnerPid -ErrorAction Stop)
    }
    catch {
        return $false
    }
}

function Get-ClosureWorkspaceOwnerMetadataStatus {
    param(
        [Parameter(Mandatory = $true)]
        [string]$MetadataPath,
        [Parameter(Mandatory = $true)]
        [int]$ExpectedPid
    )

    $status = [pscustomobject]@{
        Valid = $false
        Active = $false
    }

    $raw = Get-Content -Path $MetadataPath -Raw -ErrorAction Stop
    $pidRaw = ""
    $startRaw = ""
    $doc = $null
    try {
        $doc = [System.Text.Json.JsonDocument]::Parse($raw)
        $root = $doc.RootElement
        $pidRaw = $root.GetProperty("pid").ToString()
        $startRaw = $root.GetProperty("start_utc").GetString()
    }
    catch {
        return $status
    }
    finally {
        if ($null -ne $doc) {
            $doc.Dispose()
        }
    }

    [int]$metadataPid = 0
    if (-not [int]::TryParse([string]$pidRaw, [ref]$metadataPid) -or $metadataPid -lt 1) {
        return $status
    }

    if ([string]::IsNullOrWhiteSpace($startRaw)) {
        return $status
    }

    try {
        $metadataStartUtc = [datetime]::Parse($startRaw, [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
    }
    catch {
        return $status
    }

    $status.Valid = $true
    if ($metadataPid -ne $ExpectedPid) {
        return $status
    }

    try {
        $processStartUtc = Get-ClosureWorkspaceProcessStartUtc -OwnerPid $metadataPid
    }
    catch {
        return $status
    }

    $status.Active = ([math]::Abs(($processStartUtc - $metadataStartUtc).TotalSeconds) -lt 2)
    return $status
}

function Try-BackfillClosureWorkspaceOwnerMetadata {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$Directory,
        [Parameter(Mandatory = $true)]
        [int]$OwnerPid
    )

    try {
        $ownerStartUtc = Get-ClosureWorkspaceProcessStartUtc -OwnerPid $OwnerPid
        Set-ClosureWorkspaceOwnerMetadata -WorkspaceDir $Directory.FullName -OwnerPid $OwnerPid -OwnerStartUtc $ownerStartUtc
    }
    catch {
        # Best-effort backfill only; stale-prune safety falls back to PID-active behavior.
    }
}

function Test-ClosureWorkspaceOwnerActive {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$Directory
    )

    $pidMatch = [regex]::Match($Directory.Name, '^run-(?<pid>[0-9]+)-')
    if (-not $pidMatch.Success) {
        return $false
    }

    [int]$ownerPid = 0
    if (-not [int]::TryParse($pidMatch.Groups["pid"].Value, [ref]$ownerPid) -or $ownerPid -lt 1) {
        return $false
    }

    $pidIsActive = Test-ClosureWorkspacePidActive -OwnerPid $ownerPid
    $metadataPath = Join-Path $Directory.FullName ".fin-closure-owner.json"
    if (Test-Path $metadataPath) {
        try {
            $metadataStatus = Get-ClosureWorkspaceOwnerMetadataStatus -MetadataPath $metadataPath -ExpectedPid $ownerPid
            if (-not [bool]$metadataStatus.Valid) {
                if ($pidIsActive) {
                    Try-BackfillClosureWorkspaceOwnerMetadata -Directory $Directory -OwnerPid $ownerPid
                }
                return $pidIsActive
            }
            return [bool]$metadataStatus.Active
        }
        catch {
            if ($pidIsActive) {
                Try-BackfillClosureWorkspaceOwnerMetadata -Directory $Directory -OwnerPid $ownerPid
            }
            return $pidIsActive
        }
    }

    if ($pidIsActive) {
        Try-BackfillClosureWorkspaceOwnerMetadata -Directory $Directory -OwnerPid $ownerPid
    }

    return $pidIsActive
}

function Invoke-ClosureWorkspacePrune {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ClosureRoot
    )

    if ($env:FIN_KEEP_CLOSURE_RUNS -eq "1") {
        return
    }

    [int]$staleHours = 24
    if (-not [string]::IsNullOrWhiteSpace($env:FIN_CLOSURE_STALE_HOURS)) {
        [int]$parsedHours = 0
        if (-not [int]::TryParse($env:FIN_CLOSURE_STALE_HOURS, [ref]$parsedHours) -or $parsedHours -lt 1) {
            throw ("FIN_CLOSURE_STALE_HOURS must be a positive integer, found: {0}" -f $env:FIN_CLOSURE_STALE_HOURS)
        }
        $staleHours = $parsedHours
    }

    $staleCutoffUtc = (Get-Date).ToUniversalTime().AddHours(-1 * $staleHours)
    Get-ChildItem -Path $ClosureRoot -Directory -Filter "run-*" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.LastWriteTimeUtc -lt $staleCutoffUtc -and
            -not (Test-ClosureWorkspaceOwnerActive -Directory $_)
        } |
        ForEach-Object {
            Remove-ClosureWorkspaceDirectory -Path $_.FullName -IgnoreFailure
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
Invoke-ClosureWorkspacePrune -ClosureRoot $outDirFull

$runToken = "{0}-{1}" -f $PID, [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
$runWorkspace = Join-Path $outDirFull ("run-" + $runToken)
New-Item -ItemType Directory -Path $runWorkspace -Force | Out-Null
Set-ClosureWorkspaceOwnerMetadata -WorkspaceDir $runWorkspace -OwnerPid $PID -OwnerStartUtc (Get-ClosureWorkspaceProcessStartUtc -OwnerPid $PID)

$latestWitnessPath = Join-Path $outDirFull "stage0-closure-witness.txt"
$mirrorLatestWitness = $false
$witnessPath = $Witness
if ([string]::IsNullOrWhiteSpace($witnessPath)) {
    $witnessPath = Join-Path $runWorkspace "stage0-closure-witness.txt"
    $mirrorLatestWitness = $true
}
elseif (-not [System.IO.Path]::IsPathRooted($witnessPath)) {
    $witnessPath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $witnessPath))
}

function Invoke-ClosureCase {
    param(
        [string]$CaseId,
        [string]$Target,
        [string]$Pipeline
    )

    $isWindowsTarget = ($Target -eq "x86_64-windows-pe")
    $ext = if ($isWindowsTarget) { ".exe" } else { "" }
    $caseToken = "{0}-{1}" -f $runToken, $CaseId
    $gen1 = Join-Path $runWorkspace ("gen1-{0}{1}" -f $caseToken, $ext)
    $gen2 = Join-Path $runWorkspace ("gen2-{0}{1}" -f $caseToken, $ext)

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

$actualWitness = @{
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
    linux_pipeline_parity = $linuxParity.ToString().ToLowerInvariant()
    windows_pipeline_parity = $windowsParity.ToString().ToLowerInvariant()
    closure_equal = "true"
}

$witnessLines = [System.Collections.Generic.List[string]]::new()
foreach ($k in $requiredKeys) {
    $witnessLines.Add(("{0}={1}" -f $k, ([string]$actualWitness[$k])))
}

$witnessContent = ($witnessLines.ToArray() -join "`n") + "`n"
Write-TextFileAtomic -Path $witnessPath -Value $witnessContent

$witnessParsed = Parse-KeyValueFile -Path $witnessPath
$witnessMap = $witnessParsed.Map
$witnessKeyOrder = @($witnessParsed.OrderedKeys)
$witnessMissing = @()
$witnessMismatch = @()
$witnessUnexpected = @()
$witnessOrderMismatch = $false
$requiredOrder = ($requiredKeys -join ",")
$witnessOrder = ($witnessKeyOrder -join ",")

foreach ($k in $requiredKeys) {
    if (-not $witnessMap.ContainsKey($k)) {
        $witnessMissing += $k
        continue
    }

    if ([string]$witnessMap[$k] -ne [string]$actualWitness[$k]) {
        $witnessMismatch += ("{0}: expected={1} actual={2}" -f $k, $actualWitness[$k], $witnessMap[$k])
    }
}

foreach ($k in ($witnessMap.Keys | Sort-Object)) {
    if ($requiredKeys -notcontains $k) {
        $witnessUnexpected += $k
    }
}

if ($witnessMissing.Count -eq 0 -and $witnessUnexpected.Count -eq 0 -and $witnessOrder -ne $requiredOrder) {
    $witnessOrderMismatch = $true
}

if ($witnessMissing.Count -gt 0 -or $witnessMismatch.Count -gt 0 -or $witnessUnexpected.Count -gt 0 -or $witnessOrderMismatch) {
    $issues = @()
    if ($witnessMissing.Count -gt 0) {
        $issues += ("missing_keys={0}" -f ($witnessMissing -join ","))
    }
    if ($witnessMismatch.Count -gt 0) {
        $issues += ("mismatch={0}" -f ($witnessMismatch -join "; "))
    }
    if ($witnessUnexpected.Count -gt 0) {
        $issues += ("unexpected_keys={0}" -f ($witnessUnexpected -join ","))
    }
    if ($witnessOrderMismatch) {
        $issues += ("key_order_expected={0} actual={1}" -f $requiredOrder, $witnessOrder)
    }
    Write-Error ("Closure witness contract mismatch in {0}: {1}" -f $witnessPath, ($issues -join " | "))
    exit 1
}

if ($VerifyBaseline) {
    $baselinePath = $Baseline
    if (-not [System.IO.Path]::IsPathRooted($baselinePath)) {
        $baselinePath = [System.IO.Path]::GetFullPath((Join-Path $repoRoot $baselinePath))
    }

    $expectedParsed = Parse-KeyValueFile -Path $baselinePath
    $expected = $expectedParsed.Map
    $expectedKeyOrder = @($expectedParsed.OrderedKeys)

    $missing = @()
    $mismatch = @()
    $unexpected = @()
    $orderMismatch = $false
    $baselineOrder = ($expectedKeyOrder -join ",")
    foreach ($k in $requiredKeys) {
        if (-not $expected.ContainsKey($k)) {
            $missing += $k
            continue
        }
        if ([string]$expected[$k] -ne [string]$witnessMap[$k]) {
            $mismatch += ("{0}: expected={1} actual={2}" -f $k, $expected[$k], $witnessMap[$k])
        }
    }

    foreach ($k in ($expected.Keys | Sort-Object)) {
        if ($requiredKeys -notcontains $k) {
            $unexpected += $k
        }
    }

    if ($missing.Count -eq 0 -and $unexpected.Count -eq 0 -and $baselineOrder -ne $requiredOrder) {
        $orderMismatch = $true
    }

    if ($missing.Count -gt 0 -or $mismatch.Count -gt 0 -or $unexpected.Count -gt 0 -or $orderMismatch) {
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
        if ($orderMismatch) {
            $issues += ("key_order_expected={0} actual={1}" -f $requiredOrder, $baselineOrder)
        }
        Write-Error ("Closure baseline mismatch in {0}: {1}" -f $baselinePath, ($issues -join " | "))
        exit 1
    }

    Write-Host ("closure_baseline_verified={0}" -f $baselinePath)
}

if ($mirrorLatestWitness) {
    Write-TextFileAtomic -Path $latestWitnessPath -Value $witnessContent
}

Write-Host ("closure_mode=stage0-proxy")
Write-Host ("closure_hash={0}" -f $closureHash)
Write-Host ("witness={0}" -f $witnessPath)
if ($mirrorLatestWitness) {
    Write-Host ("witness_latest={0}" -f $latestWitnessPath)
}
Write-Host ("run_workspace={0}" -f $runWorkspace)
Write-Host "stage0 closure check passed."

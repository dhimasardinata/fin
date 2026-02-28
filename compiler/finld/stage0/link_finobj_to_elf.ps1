param(
    [string[]]$ObjectPath = @("artifacts/main.finobj"),
    [string]$OutFile = "artifacts/main-linked",
    [ValidateSet("x86_64-linux-elf", "x86_64-windows-pe")]
    [string]$Target = "x86_64-linux-elf",
    [switch]$Verify,
    [switch]$AsRecord
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..\\..")
$reader = Join-Path $repoRoot "compiler/finobj/stage0/read_finobj_exit.ps1"
$emitElf = Join-Path $repoRoot "compiler/finc/stage0/emit_elf_exit0.ps1"
$emitPe = Join-Path $repoRoot "compiler/finc/stage0/emit_pe_exit0.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$verifyPe = Join-Path $repoRoot "tests/bootstrap/verify_pe_exit0.ps1"

function Get-TextSha256 {
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

if ($null -eq $ObjectPath -or $ObjectPath.Count -eq 0) {
    throw "At least one finobj path is required."
}

$objectPaths = [System.Collections.Generic.List[string]]::new()
$seenObjectPaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($path in $ObjectPath) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        continue
    }

    $objFull = if ([System.IO.Path]::IsPathRooted($path)) {
        [System.IO.Path]::GetFullPath($path)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $path))
    }

    if (-not (Test-Path $objFull)) {
        throw "finobj file not found: $objFull"
    }
    if (-not $seenObjectPaths.Add($objFull)) {
        throw "Duplicate finobj path provided: $objFull"
    }

    $objectPaths.Add($objFull)
}
if ($objectPaths.Count -eq 0) {
    throw "At least one non-empty finobj path is required."
}

$outFull = if ([System.IO.Path]::IsPathRooted($OutFile)) {
    [System.IO.Path]::GetFullPath($OutFile)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutFile))
}

$records = [System.Collections.Generic.List[object]]::new()
foreach ($obj in $objectPaths) {
    $records.Add((& $reader -ObjectPath $obj -ExpectedTarget $Target -AsRecord))
}

$seenObjectIdentities = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($record in $records) {
    $identity = ("{0}|{1}|{2}" -f $record.EntrySymbol, $record.SourcePath, $record.SourceSha256)
    if (-not $seenObjectIdentities.Add($identity)) {
        throw ("Duplicate finobj identity detected: {0}" -f $identity)
    }
}

$orderedRecords = @($records | Sort-Object `
        @{Expression = { if ($_.EntrySymbol -eq "main") { 0 } else { 1 } } }, `
        @{Expression = { $_.SourcePath } }, `
        @{Expression = { $_.SourceSha256 } })

$entryRecords = @($orderedRecords | Where-Object { $_.EntrySymbol -eq "main" })
if ($entryRecords.Count -eq 0) {
    throw "Link requires exactly one entry object with entry_symbol=main; found none."
}
if ($entryRecords.Count -gt 1) {
    throw ("Link requires exactly one entry object with entry_symbol=main; found {0}." -f $entryRecords.Count)
}

$entryRecord = $entryRecords[0]

$symbolProviders = @{}
$requiredCount = 0
$relocationCount = 0
foreach ($record in $orderedRecords) {
    foreach ($symbol in @($record.ProvidedSymbols)) {
        if ($symbolProviders.ContainsKey($symbol)) {
            $existing = $symbolProviders[$symbol]
            throw ("Duplicate symbol provider detected for '{0}': {1} and {2}" -f $symbol, $existing.SourcePath, $record.SourcePath)
        }
        $symbolProviders[$symbol] = $record
    }
    $requiredCount += @($record.RequiredSymbols).Count
    $relocationCount += @($record.Relocations).Count
}

if (-not $symbolProviders.ContainsKey("main")) {
    throw "Link requires symbol provider for 'main'; none found."
}

$mainProvider = $symbolProviders["main"]
if ([string]$mainProvider.ObjectPath -ne [string]$entryRecord.ObjectPath) {
    throw ("Entry object mismatch: entry_symbol=main object '{0}' does not provide symbol 'main' (provided by '{1}')." -f $entryRecord.SourcePath, $mainProvider.SourcePath)
}

$unresolved = [System.Collections.Generic.List[string]]::new()
foreach ($record in $orderedRecords) {
    foreach ($symbol in @($record.RequiredSymbols)) {
        if (-not $symbolProviders.ContainsKey($symbol)) {
            $unresolved.Add(("{0} (required by {1})" -f $symbol, $record.SourcePath))
        }
    }
}
if ($unresolved.Count -gt 0) {
    throw ("Unresolved symbols detected: {0}" -f (($unresolved.ToArray() | Sort-Object) -join "; "))
}

$symbolResolutionLines = [System.Collections.Generic.List[string]]::new()
foreach ($record in $orderedRecords) {
    foreach ($symbol in @($record.RequiredSymbols | Sort-Object)) {
        $resolvedProvider = $symbolProviders[$symbol]
        $symbolResolutionLines.Add(("{0}|{1}|{2}|{3}" -f `
                $record.SourcePath, `
                $symbol, `
                $resolvedProvider.SourcePath, `
                $resolvedProvider.EntrySymbol))
    }
}
$symbolResolutionPayload = ($symbolResolutionLines.ToArray() -join "`n") + "`n"
$symbolResolutionHash = Get-TextSha256 -Text $symbolResolutionPayload

$unresolvedRelocations = [System.Collections.Generic.List[string]]::new()
foreach ($record in $orderedRecords) {
    foreach ($reloc in @($record.Relocations)) {
        if (-not $symbolProviders.ContainsKey($reloc.Symbol)) {
            $unresolvedRelocations.Add(("{0} (from {1})" -f $reloc.Key, $record.SourcePath))
        }
    }
}
if ($unresolvedRelocations.Count -gt 0) {
    throw ("Unresolved relocations detected: {0}" -f (($unresolvedRelocations.ToArray() | Sort-Object) -join "; "))
}

$relocationResolutionLines = [System.Collections.Generic.List[string]]::new()
foreach ($record in $orderedRecords) {
    foreach ($reloc in @($record.Relocations | Sort-Object @{Expression = { [UInt64]$_.Offset } }, @{Expression = { $_.Symbol } })) {
        $resolvedProvider = $symbolProviders[$reloc.Symbol]
        $relocationResolutionLines.Add(("{0}|{1}|{2}|{3}|{4}" -f `
                $record.SourcePath, `
                $reloc.Offset, `
                $reloc.Symbol, `
                $resolvedProvider.SourcePath, `
                $resolvedProvider.EntrySymbol))
    }
}
$relocationResolutionPayload = ($relocationResolutionLines.ToArray() -join "`n") + "`n"
$relocationResolutionHash = Get-TextSha256 -Text $relocationResolutionPayload

$objectSetLines = [System.Collections.Generic.List[string]]::new()
foreach ($record in $orderedRecords) {
    $relocationKeys = @($record.Relocations | Sort-Object @{Expression = { [UInt64]$_.Offset } }, @{Expression = { $_.Symbol } } | ForEach-Object { $_.Key })
    $objectSetLines.Add(("{0}|{1}|{2}|{3}|{4}|{5}|{6}" -f `
            $record.EntrySymbol, `
            $record.SourcePath, `
            $record.SourceSha256, `
            $record.ExitCode, `
            (@($record.ProvidedSymbols) -join ","), `
            (@($record.RequiredSymbols) -join ","), `
            ($relocationKeys -join ",")))
}
$objectSetPayload = ($objectSetLines.ToArray() -join "`n") + "`n"
$objectSetHash = Get-TextSha256 -Text $objectSetPayload
[int]$exitCode = [int]$entryRecord.ExitCode
if ($Target -eq "x86_64-linux-elf") {
    & $emitElf -OutFile $outFull -ExitCode $exitCode
}
elseif ($Target -eq "x86_64-windows-pe") {
    & $emitPe -OutFile $outFull -ExitCode $exitCode
}
else {
    throw "Unsupported target: $Target"
}

if ($Verify) {
    if ($Target -eq "x86_64-linux-elf") {
        & $verifyElf -Path $outFull -ExpectedExitCode $exitCode
    }
    else {
        & $verifyPe -Path $outFull -ExpectedExitCode $exitCode
    }
}

$report = [ordered]@{
    LinkedObject = [string]$entryRecord.ObjectPath
    LinkedObjectsCount = [int]$orderedRecords.Count
    LinkedNonEntryObjectsCount = [int](@($orderedRecords | Where-Object { $_.EntrySymbol -ne "main" }).Count)
    LinkedSymbolsDefinedCount = [int]$symbolProviders.Count
    LinkedSymbolsRequiredCount = [int]$requiredCount
    LinkedRelocationCount = [int]$relocationCount
    LinkedSymbolResolutionSha256 = [string]$symbolResolutionHash
    LinkedRelocationResolutionSha256 = [string]$relocationResolutionHash
    LinkedObjectSetSha256 = [string]$objectSetHash
    LinkedOutput = [string]$outFull
    LinkedTarget = [string]$Target
    ProgramExitCode = [int]$exitCode
}

Write-Host ("linked_object={0}" -f $report.LinkedObject)
Write-Host ("linked_objects_count={0}" -f $report.LinkedObjectsCount)
Write-Host ("linked_non_entry_objects_count={0}" -f $report.LinkedNonEntryObjectsCount)
Write-Host ("linked_symbols_defined_count={0}" -f $report.LinkedSymbolsDefinedCount)
Write-Host ("linked_symbols_required_count={0}" -f $report.LinkedSymbolsRequiredCount)
Write-Host ("linked_relocation_count={0}" -f $report.LinkedRelocationCount)
Write-Host ("linked_symbol_resolution_sha256={0}" -f $report.LinkedSymbolResolutionSha256)
Write-Host ("linked_relocation_resolution_sha256={0}" -f $report.LinkedRelocationResolutionSha256)
Write-Host ("linked_object_set_sha256={0}" -f $report.LinkedObjectSetSha256)
Write-Host ("linked_output={0}" -f $report.LinkedOutput)
Write-Host ("linked_target={0}" -f $report.LinkedTarget)
Write-Host ("program_exit_code={0}" -f $report.ProgramExitCode)

if ($AsRecord) {
    Write-Output ([pscustomobject]$report)
}

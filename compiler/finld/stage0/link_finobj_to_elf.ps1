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

function Get-Stage0CodeLayout {
    param([string]$LinkTarget)

    if ($LinkTarget -eq "x86_64-linux-elf") {
        return [pscustomobject]@{
            CodeOffset = [UInt32](64 + 56)
            CodeSize = [UInt32]12
            AllowedRelocationOffsets = @([UInt32]6)
            AllowedRelocationKinds = @("abs32", "rel32")
        }
    }
    if ($LinkTarget -eq "x86_64-windows-pe") {
        return [pscustomobject]@{
            CodeOffset = [UInt32]0x200
            CodeSize = [UInt32]6
            AllowedRelocationOffsets = @([UInt32]1)
            AllowedRelocationKinds = @("abs32")
        }
    }

    throw ("Unsupported target for stage0 relocation layout: {0}" -f $LinkTarget)
}

function Resolve-RelocationValue {
    param(
        [string]$Kind,
        [UInt32]$Offset,
        [UInt32]$SymbolValue
    )

    if ($Kind -eq "abs32") {
        [UInt64]$value = [UInt64]$SymbolValue
        if ($value -gt [UInt64][UInt32]::MaxValue) {
            throw ("relocation abs32 value overflow at offset {0}" -f $Offset)
        }
        return [pscustomobject]@{
            Kind = "abs32"
            ValueText = ("u32:{0}" -f $value)
            SignedValue = [Int64]$value
            UnsignedValue = [UInt32]$value
        }
    }

    if ($Kind -eq "rel32") {
        [Int64]$delta = [Int64]$SymbolValue - ([Int64]$Offset + 4)
        if ($delta -lt [Int64][Int32]::MinValue -or $delta -gt [Int64][Int32]::MaxValue) {
            throw ("relocation rel32 overflow at offset {0}: {1}" -f $Offset, $delta)
        }
        return [pscustomobject]@{
            Kind = "rel32"
            ValueText = ("i32:{0}" -f $delta)
            SignedValue = [Int64]$delta
            UnsignedValue = [UInt32]0
        }
    }

    throw ("Unsupported relocation kind in stage0 linker: {0}" -f $Kind)
}

function Get-RecordSymbolValue {
    param(
        [object]$Record,
        [string]$Symbol
    )

    $valuesProperty = $Record.PSObject.Properties["ProvidedSymbolValues"]
    if ($null -eq $valuesProperty -or $null -eq $valuesProperty.Value) {
        return [UInt32]$Record.ExitCode
    }

    $values = $valuesProperty.Value
    if ($values -is [System.Collections.IDictionary]) {
        if ($values.Contains($Symbol)) {
            return [UInt32]$values[$Symbol]
        }
    }

    if (@($Record.ProvidedSymbols) -contains $Symbol) {
        return [UInt32]$Record.ExitCode
    }

    throw ("Missing symbol value metadata for '{0}' in object '{1}'." -f $Symbol, $Record.SourcePath)
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
            throw ("Duplicate symbol provider detected for '{0}': {1} and {2}" -f $symbol, $existing.Record.SourcePath, $record.SourcePath)
        }
        $symbolProviders[$symbol] = [pscustomobject]@{
            Record = $record
            Symbol = $symbol
            SymbolValue = (Get-RecordSymbolValue -Record $record -Symbol $symbol)
        }
    }
    $requiredCount += @($record.RequiredSymbols).Count
    $relocationCount += @($record.Relocations).Count
}

if (-not $symbolProviders.ContainsKey("main")) {
    throw "Link requires symbol provider for 'main'; none found."
}

$mainProvider = $symbolProviders["main"]
if ([string]$mainProvider.Record.ObjectPath -ne [string]$entryRecord.ObjectPath) {
    throw ("Entry object mismatch: entry_symbol=main object '{0}' does not provide symbol 'main' (provided by '{1}')." -f $entryRecord.SourcePath, $mainProvider.Record.SourcePath)
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
                $resolvedProvider.Record.SourcePath, `
                $resolvedProvider.Record.EntrySymbol))
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

$nonEntryRelocations = [System.Collections.Generic.List[string]]::new()
foreach ($record in @($orderedRecords | Where-Object { $_.EntrySymbol -ne "main" })) {
    foreach ($reloc in @($record.Relocations)) {
        $nonEntryRelocations.Add(("{0} (from {1})" -f $reloc.Key, $record.SourcePath))
    }
}
if ($nonEntryRelocations.Count -gt 0) {
    throw ("Stage0 relocation materialization supports entry object relocations only: {0}" -f (($nonEntryRelocations.ToArray() | Sort-Object) -join "; "))
}

$layout = Get-Stage0CodeLayout -LinkTarget $Target
$allowedKinds = @($layout.AllowedRelocationKinds)

$relocationPlans = [System.Collections.Generic.List[object]]::new()
$relocationResolutionLines = [System.Collections.Generic.List[string]]::new()
foreach ($record in $orderedRecords) {
    foreach ($reloc in @($record.Relocations | Sort-Object @{Expression = { [UInt64]$_.Offset } }, @{Expression = { $_.Symbol } }, @{Expression = { $_.Kind } })) {
        if (-not ($allowedKinds -contains [string]$reloc.Kind)) {
            throw ("Relocation kind not supported for stage0 {0}: {1} (allowed: {2})" -f `
                    $Target, `
                    $reloc.Key, `
                    ($allowedKinds -join ","))
        }
        $resolvedProvider = $symbolProviders[$reloc.Symbol]
        $resolvedValue = Resolve-RelocationValue -Kind $reloc.Kind -Offset ([UInt32]$reloc.Offset) -SymbolValue ([UInt32]$resolvedProvider.SymbolValue)
        $relocationPlans.Add([pscustomobject]@{
                Record = $record
                Relocation = $reloc
                Provider = $resolvedProvider
                ResolvedValue = $resolvedValue
            })
        $relocationResolutionLines.Add(("{0}|{1}|{2}|{3}|{4}|{5}|{6}" -f `
                $record.SourcePath, `
                $reloc.Offset, `
                $reloc.Symbol, `
                $reloc.Kind, `
                $resolvedProvider.Record.SourcePath, `
                $resolvedProvider.Record.EntrySymbol, `
                $resolvedValue.ValueText))
    }
}
$relocationResolutionPayload = ($relocationResolutionLines.ToArray() -join "`n") + "`n"
$relocationResolutionHash = Get-TextSha256 -Text $relocationResolutionPayload

$objectSetLines = [System.Collections.Generic.List[string]]::new()
foreach ($record in $orderedRecords) {
    $relocationKeys = @($record.Relocations | Sort-Object @{Expression = { [UInt64]$_.Offset } }, @{Expression = { $_.Symbol } }, @{Expression = { $_.Kind } } | ForEach-Object { $_.Key })
    $symbolValueKeys = @($record.ProvidedSymbols | ForEach-Object { "{0}={1}" -f $_, (Get-RecordSymbolValue -Record $record -Symbol $_) })
    $objectSetLines.Add(("{0}|{1}|{2}|{3}|{4}|{5}|{6}|{7}" -f `
            $record.EntrySymbol, `
            $record.SourcePath, `
            $record.SourceSha256, `
            $record.ExitCode, `
            (@($record.ProvidedSymbols) -join ","), `
            (@($record.RequiredSymbols) -join ","), `
            ($relocationKeys -join ","), `
            ($symbolValueKeys -join ",")))
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

$entryRelocationPlans = @($relocationPlans | Where-Object { [string]$_.Record.ObjectPath -eq [string]$entryRecord.ObjectPath } | Sort-Object `
        @{Expression = { [UInt64]$_.Relocation.Offset } }, `
        @{Expression = { $_.Relocation.Symbol } }, `
        @{Expression = { $_.Relocation.Kind } })
[int]$relocationAppliedCount = $entryRelocationPlans.Count

if ($entryRelocationPlans.Count -gt 0) {
    [byte[]]$imageBytes = [System.IO.File]::ReadAllBytes($outFull)

    foreach ($plan in $entryRelocationPlans) {
        [UInt64]$relocOffset = [UInt64]$plan.Relocation.Offset
        if ($relocOffset + 4 -gt [UInt64]$layout.CodeSize) {
            throw ("Relocation offset out of stage0 {0} code bounds ({1} bytes): {2}" -f $Target, $layout.CodeSize, $plan.Relocation.Key)
        }
        $allowedOffsets = @($layout.AllowedRelocationOffsets)
        $siteSupported = $false
        foreach ($allowed in $allowedOffsets) {
            if ([UInt32]$allowed -eq [UInt32]$plan.Relocation.Offset) {
                $siteSupported = $true
                break
            }
        }
        if (-not $siteSupported) {
            throw ("Relocation offset not supported for stage0 {0}: {1} (allowed: {2})" -f `
                    $Target, `
                    $plan.Relocation.Key, `
                    (($allowedOffsets | ForEach-Object { [string]$_ }) -join ","))
        }

        [UInt64]$fileOffset = [UInt64]$layout.CodeOffset + $relocOffset
        if ($fileOffset + 4 -gt [UInt64]$imageBytes.LongLength) {
            throw ("Relocation file offset out of bounds: {0}" -f $plan.Relocation.Key)
        }

        [byte[]]$patchBytes = if ($plan.Relocation.Kind -eq "abs32") {
            [System.BitConverter]::GetBytes([UInt32]$plan.ResolvedValue.UnsignedValue)
        }
        else {
            [System.BitConverter]::GetBytes([Int32]$plan.ResolvedValue.SignedValue)
        }
        if (-not [System.BitConverter]::IsLittleEndian) {
            [Array]::Reverse($patchBytes)
        }

        [int]$site = [int]$fileOffset
        for ($i = 0; $i -lt 4; $i++) {
            $imageBytes[$site + $i] = $patchBytes[$i]
        }
    }

    [System.IO.File]::WriteAllBytes($outFull, $imageBytes)
}

if ($Verify) {
    if ($entryRelocationPlans.Count -gt 0) {
        Write-Host "verify_mode=structure_only_relocation_patched"
        if ($Target -eq "x86_64-linux-elf") {
            & $verifyElf -Path $outFull -ExpectedExitCode $exitCode -AllowPatchedCode
        }
        else {
            & $verifyPe -Path $outFull -ExpectedExitCode $exitCode -AllowPatchedCode
        }
    }
    else {
        if ($Target -eq "x86_64-linux-elf") {
            & $verifyElf -Path $outFull -ExpectedExitCode $exitCode
        }
        else {
            & $verifyPe -Path $outFull -ExpectedExitCode $exitCode
        }
    }
}

$report = [ordered]@{
    LinkedObject = [string]$entryRecord.ObjectPath
    LinkedObjectsCount = [int]$orderedRecords.Count
    LinkedNonEntryObjectsCount = [int](@($orderedRecords | Where-Object { $_.EntrySymbol -ne "main" }).Count)
    LinkedSymbolsDefinedCount = [int]$symbolProviders.Count
    LinkedSymbolsRequiredCount = [int]$requiredCount
    LinkedRelocationCount = [int]$relocationCount
    LinkedRelocationsAppliedCount = [int]$relocationAppliedCount
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
Write-Host ("linked_relocations_applied_count={0}" -f $report.LinkedRelocationsAppliedCount)
Write-Host ("linked_symbol_resolution_sha256={0}" -f $report.LinkedSymbolResolutionSha256)
Write-Host ("linked_relocation_resolution_sha256={0}" -f $report.LinkedRelocationResolutionSha256)
Write-Host ("linked_object_set_sha256={0}" -f $report.LinkedObjectSetSha256)
Write-Host ("linked_output={0}" -f $report.LinkedOutput)
Write-Host ("linked_target={0}" -f $report.LinkedTarget)
Write-Host ("program_exit_code={0}" -f $report.ProgramExitCode)

if ($AsRecord) {
    Write-Output ([pscustomobject]$report)
}

param(
    [string]$ObjectPath = "artifacts/main.finobj",
    [string]$ExpectedTarget = "",
    [switch]$AsRecord
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$objFull = [System.IO.Path]::GetFullPath($ObjectPath)
if (-not (Test-Path $objFull)) {
    throw "finobj file not found: $objFull"
}

function Assert-SupportedTarget {
    param([string]$Target)

    if ($Target -ne "x86_64-linux-elf" -and $Target -ne "x86_64-windows-pe") {
        throw "Unsupported target: $Target"
    }
}

function Parse-SymbolList {
    param(
        [string]$RawValue,
        [string]$Key
    )

    if ([string]::IsNullOrWhiteSpace($RawValue)) {
        return @()
    }

    $symbols = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($part in ($RawValue -split ",")) {
        $symbol = $part.Trim()
        if ([string]::IsNullOrWhiteSpace($symbol)) {
            continue
        }
        if ($symbol -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
            throw ("Invalid {0} symbol: {1}" -f $Key, $symbol)
        }
        if (-not $seen.Add($symbol)) {
            throw ("Duplicate {0} symbol: {1}" -f $Key, $symbol)
        }
        $symbols.Add($symbol)
    }

    $ordered = @($symbols | Sort-Object `
            @{Expression = { if ($_ -eq "main") { 0 } else { 1 } } }, `
            @{Expression = { $_ } })
    return @($ordered)
}

function Parse-RelocationList {
    param([string]$RawValue)

    if ([string]::IsNullOrWhiteSpace($RawValue)) {
        return @()
    }

    $relocations = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $seenOffsets = [System.Collections.Generic.HashSet[UInt32]]::new()

    foreach ($part in ($RawValue -split '[,;]')) {
        $token = $part.Trim()
        if ([string]::IsNullOrWhiteSpace($token)) {
            continue
        }
        if ($token -notmatch '^([A-Za-z_][A-Za-z0-9_]*)@([0-9]+)(?::([A-Za-z0-9_]+))?$') {
            throw ("Invalid relocs entry: {0}. Expected <symbol>@<offset>[:<kind>]." -f $token)
        }

        $symbol = $Matches[1]
        [UInt64]$offset = 0
        if (-not [UInt64]::TryParse($Matches[2], [ref]$offset)) {
            throw ("Invalid relocation offset: {0}" -f $Matches[2])
        }
        if ($offset -gt [UInt32]::MaxValue) {
            throw ("Relocation offset out of stage0 range (0..4294967295): {0}" -f $offset)
        }
        $kind = if ([string]::IsNullOrWhiteSpace($Matches[3])) { "abs32" } else { $Matches[3].ToLowerInvariant() }
        if ($kind -ne "abs32" -and $kind -ne "rel32") {
            throw ("Unsupported relocation kind in stage0: {0}" -f $kind)
        }

        $normalized = ("{0}@{1}:{2}" -f $symbol, $offset, $kind)
        if (-not $seen.Add($normalized)) {
            throw ("Duplicate relocs entry: {0}" -f $normalized)
        }
        $offset32 = [UInt32]$offset
        if (-not $seenOffsets.Add($offset32)) {
            throw ("Duplicate relocation offset: {0}" -f $offset32)
        }

        $relocations.Add([pscustomobject]@{
                Symbol = $symbol
                Offset = $offset32
                Kind = $kind
                Key = $normalized
            })
    }

    $ordered = @($relocations | Sort-Object @{Expression = { [UInt64]$_.Offset } }, @{Expression = { $_.Symbol } }, @{Expression = { $_.Kind } })
    return @($ordered)
}

$raw = Get-Content -Path $objFull -Raw
$map = @{}
foreach ($line in ([regex]::Split($raw, "`r?`n"))) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
    if ($trimmed.StartsWith("#")) { continue }
    if ($trimmed -notmatch '^([A-Za-z0-9_.-]+)\s*=\s*(.*)$') {
        throw "Invalid finobj line: $trimmed"
    }
    $key = $Matches[1]
    if ($map.ContainsKey($key)) {
        throw "Duplicate finobj key: $key"
    }
    $map[$key] = $Matches[2].Trim()
}

$required = @(
    "finobj_format",
    "finobj_version",
    "target",
    "entry_symbol",
    "exit_code",
    "source_path",
    "source_sha256"
)
foreach ($k in $required) {
    if (-not $map.ContainsKey($k)) {
        throw "Missing finobj key: $k"
    }
}

if ($map["finobj_format"] -ne "finobj-stage0") {
    throw "Unsupported finobj format: $($map["finobj_format"])"
}
if ($map["finobj_version"] -ne "1") {
    throw "Unsupported finobj version: $($map["finobj_version"])"
}
$entrySymbol = $map["entry_symbol"]
if ($entrySymbol -ne "main" -and $entrySymbol -ne "unit") {
    throw "Unsupported entry_symbol: $entrySymbol"
}
Assert-SupportedTarget -Target $map["target"]
if (-not [string]::IsNullOrWhiteSpace($ExpectedTarget)) {
    Assert-SupportedTarget -Target $ExpectedTarget
    if ($map["target"] -ne $ExpectedTarget) {
        throw "finobj target mismatch: expected '$ExpectedTarget', got '$($map["target"])'"
    }
}

$sourcePath = $map["source_path"]
if ([string]::IsNullOrWhiteSpace($sourcePath)) {
    throw "Invalid source_path: value is empty"
}
if ($sourcePath.Contains("\")) {
    throw "Invalid source_path: must use '/' separators"
}
if ([System.IO.Path]::IsPathRooted($sourcePath)) {
    throw "Invalid source_path: must be repository-relative"
}
if ($sourcePath -match '^[A-Za-z]:/') {
    throw "Invalid source_path: Windows drive-root paths are not allowed"
}
if ($sourcePath -match '(^|/)\.\.(/|$)') {
    throw "Invalid source_path: parent traversal segments are not allowed"
}

$sourceHash = $map["source_sha256"]
if ($sourceHash -notmatch '^[0-9a-fA-F]{64}$') {
    throw "Invalid source_sha256: expected 64 hex characters"
}

$providedSymbols = @(if ($map.ContainsKey("provides")) {
        Parse-SymbolList -RawValue $map["provides"] -Key "provides"
    }
    else {
        if ($entrySymbol -eq "main") {
            "main"
        }
    })

$requiredSymbols = @(if ($map.ContainsKey("requires")) {
        Parse-SymbolList -RawValue $map["requires"] -Key "requires"
    })

$relocations = @(if ($map.ContainsKey("relocs")) {
        Parse-RelocationList -RawValue $map["relocs"]
    })

$providedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($symbol in $providedSymbols) {
    [void]$providedSet.Add($symbol)
}
foreach ($symbol in $requiredSymbols) {
    if ($providedSet.Contains($symbol)) {
        throw ("Symbol cannot appear in both provides and requires: {0}" -f $symbol)
    }
}

$requiredSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($symbol in $requiredSymbols) {
    [void]$requiredSet.Add($symbol)
}
foreach ($reloc in $relocations) {
    if ($providedSet.Contains($reloc.Symbol)) {
        throw ("Relocation symbol cannot be locally provided in stage0: {0}" -f $reloc.Symbol)
    }
    if (-not $requiredSet.Contains($reloc.Symbol)) {
        throw ("Relocation symbol must be listed in requires: {0}" -f $reloc.Symbol)
    }
}

[int]$exitCode = 0
if (-not [int]::TryParse($map["exit_code"], [ref]$exitCode)) {
    throw "Invalid exit_code value: $($map["exit_code"])"
}
if ($exitCode -lt 0 -or $exitCode -gt 255) {
    throw "finobj exit_code out of range 0..255: $exitCode"
}

Write-Host ("finobj_read={0}" -f $objFull)
Write-Host ("target={0}" -f $map["target"])
Write-Host ("entry_symbol={0}" -f $entrySymbol)
Write-Host ("provides={0}" -f ($providedSymbols -join ","))
Write-Host ("requires={0}" -f ($requiredSymbols -join ","))
Write-Host ("relocs={0}" -f ((@($relocations | ForEach-Object { $_.Key }) -join ",")))
if ($AsRecord) {
    Write-Output ([pscustomobject]@{
            ObjectPath = $objFull
            Target = $map["target"]
            EntrySymbol = $entrySymbol
            ExitCode = $exitCode
            SourcePath = $sourcePath
            SourceSha256 = $sourceHash
            ProvidedSymbols = $providedSymbols
            RequiredSymbols = $requiredSymbols
            Relocations = $relocations
        })
    return
}

Write-Output $exitCode

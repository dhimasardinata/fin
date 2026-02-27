param(
    [string]$SourcePath = "src/main.fn",
    [string]$OutFile = "artifacts/main.finobj",
    [ValidateSet("x86_64-linux-elf", "x86_64-windows-pe")]
    [string]$Target = "x86_64-linux-elf",
    [ValidateSet("main", "unit")]
    [string]$EntrySymbol = "main",
    [string[]]$Provides = @(),
    [string[]]$Requires = @(),
    [string[]]$Relocs = @()
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..\\..")
$parser = Join-Path $repoRoot "compiler/finc/stage0/parse_main_exit.ps1"

function Normalize-Text {
    param([string]$Text)
    return (($Text -replace "`r`n", "`n") -replace "`r", "`n")
}

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

function Get-NormalizedSymbolList {
    param(
        [string[]]$Items,
        [string]$Label
    )

    $symbols = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    foreach ($item in $Items) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        foreach ($part in ($item -split ",")) {
            $symbol = $part.Trim()
            if ([string]::IsNullOrWhiteSpace($symbol)) {
                continue
            }
            if ($symbol -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
                throw ("Invalid {0} symbol: {1}" -f $Label, $symbol)
            }
            if (-not $seen.Add($symbol)) {
                throw ("Duplicate {0} symbol: {1}" -f $Label, $symbol)
            }
            $symbols.Add($symbol)
        }
    }

    return @($symbols.ToArray())
}

function Get-NormalizedRelocationList {
    param([string[]]$Items)

    $relocations = [System.Collections.Generic.List[object]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $seenOffsets = [System.Collections.Generic.HashSet[UInt32]]::new()

    foreach ($item in $Items) {
        if ([string]::IsNullOrWhiteSpace($item)) {
            continue
        }

        foreach ($part in ($item -split '[,;]')) {
            $token = $part.Trim()
            if ([string]::IsNullOrWhiteSpace($token)) {
                continue
            }

            if ($token -notmatch '^([A-Za-z_][A-Za-z0-9_]*)@([0-9]+)$') {
                throw ("Invalid relocation entry: {0}. Expected <symbol>@<offset>." -f $token)
            }

            $symbol = $Matches[1]
            [UInt64]$offset = 0
            if (-not [UInt64]::TryParse($Matches[2], [ref]$offset)) {
                throw ("Invalid relocation offset: {0}" -f $Matches[2])
            }
            if ($offset -gt [UInt32]::MaxValue) {
                throw ("Relocation offset out of stage0 range (0..4294967295): {0}" -f $offset)
            }

            $normalized = ("{0}@{1}" -f $symbol, $offset)
            if (-not $seen.Add($normalized)) {
                throw ("Duplicate relocation entry: {0}" -f $normalized)
            }
            $offset32 = [UInt32]$offset
            if (-not $seenOffsets.Add($offset32)) {
                throw ("Duplicate relocation offset: {0}" -f $offset32)
            }

            $relocations.Add([pscustomobject]@{
                    Symbol = $symbol
                    Offset = $offset32
                    Key = $normalized
                })
        }
    }

    $ordered = @($relocations | Sort-Object @{Expression = { [UInt64]$_.Offset } }, @{Expression = { $_.Symbol } })
    return @($ordered)
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

$sourceFull = if ([System.IO.Path]::IsPathRooted($SourcePath)) {
    [System.IO.Path]::GetFullPath($SourcePath)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $SourcePath))
}

if (-not (Test-Path $sourceFull)) {
    throw "Source file not found: $sourceFull"
}

$outFull = if ([System.IO.Path]::IsPathRooted($OutFile)) {
    [System.IO.Path]::GetFullPath($OutFile)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutFile))
}

$outDir = Split-Path -Parent $outFull
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

[int]$exitCode = [int](& $parser -SourcePath $sourceFull)
$rawSource = Get-Content -Path $sourceFull -Raw
$sourceHash = Get-TextSha256 -Text (Normalize-Text -Text $rawSource)
$sourceRel = Get-RelativePathNormalized -BasePath $repoRoot -FullPath $sourceFull
$providedSymbols = @(Get-NormalizedSymbolList -Items $Provides -Label "provides")
$requiredSymbols = @(Get-NormalizedSymbolList -Items $Requires -Label "requires")
$relocations = @(Get-NormalizedRelocationList -Items $Relocs)

if ($providedSymbols.Count -eq 0 -and $EntrySymbol -eq "main") {
    $providedSymbols = @("main")
}

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

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("finobj_format=finobj-stage0")
$lines.Add("finobj_version=1")
$lines.Add(("target={0}" -f $Target))
$lines.Add(("entry_symbol={0}" -f $EntrySymbol))
$lines.Add(("exit_code={0}" -f $exitCode))
$lines.Add(("source_path={0}" -f $sourceRel))
$lines.Add(("source_sha256={0}" -f $sourceHash))
$lines.Add(("provides={0}" -f ($providedSymbols -join ",")))
$lines.Add(("requires={0}" -f ($requiredSymbols -join ",")))
$lines.Add(("relocs={0}" -f ((@($relocations | ForEach-Object { $_.Key }) -join ","))))

$content = ($lines.ToArray() -join "`n") + "`n"
Set-Content -Path $outFull -Value $content -NoNewline

$objHash = (Get-FileHash -Path $outFull -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ("finobj_written={0}" -f $outFull)
Write-Host ("exit_code={0}" -f $exitCode)
Write-Host ("finobj_sha256={0}" -f $objHash)

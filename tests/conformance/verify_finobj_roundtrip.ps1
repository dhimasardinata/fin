Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$writer = Join-Path $repoRoot "compiler/finobj/stage0/write_finobj_exit.ps1"
$reader = Join-Path $repoRoot "compiler/finobj/stage0/read_finobj_exit.ps1"
$tmpDir = Join-Path $repoRoot "artifacts/tmp/finobj-roundtrip"

if (Test-Path $tmpDir) {
    Remove-Item -Recurse -Force $tmpDir
}
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

$source = Join-Path $repoRoot "tests/conformance/fixtures/main_exit7.fn"
$objA = Join-Path $tmpDir "a.finobj"
$objB = Join-Path $tmpDir "b.finobj"
$objWin = Join-Path $tmpDir "win.finobj"
$objUnit = Join-Path $tmpDir "unit.finobj"
$objSymbols = Join-Path $tmpDir "symbols.finobj"
$objSymbolsManualOrder = Join-Path $tmpDir "symbols-manual-order.finobj"
$objRelocs = Join-Path $tmpDir "relocs.finobj"

function Assert-ReaderFails {
    param(
        [string]$Path,
        [string]$Label
    )

    $failed = $false
    try {
        & $reader -ObjectPath $Path | Out-Null
    }
    catch {
        $failed = $true
    }
    if (-not $failed) {
        Write-Error ("Expected finobj reader failure: {0}" -f $Label)
        exit 1
    }
}

& $writer -SourcePath $source -OutFile $objA
& $writer -SourcePath $source -OutFile $objB
& $writer -SourcePath $source -OutFile $objWin -Target x86_64-windows-pe
& $writer -SourcePath $source -OutFile $objUnit -EntrySymbol unit
& $writer -SourcePath $source -OutFile $objSymbols -Provides @("helper", "main") -Requires @("dep_b", "dep_a")
& $writer -SourcePath $source -OutFile $objRelocs -Provides @("main", "helper") -Requires @("dep_a", "dep_b") -Relocs @("dep_b@32:rel32", "dep_a@16")

$hashA = (Get-FileHash -Path $objA -Algorithm SHA256).Hash
$hashB = (Get-FileHash -Path $objB -Algorithm SHA256).Hash
if ($hashA -ne $hashB) {
    Write-Error "Expected deterministic finobj writer output hash."
    exit 1
}

$exitCode = [int](& $reader -ObjectPath $objA)
if ($exitCode -ne 7) {
    Write-Error ("Expected finobj reader exit code 7, got {0}" -f $exitCode)
    exit 1
}

$mainRecord = & $reader -ObjectPath $objA -ExpectedTarget x86_64-linux-elf -AsRecord
if (@($mainRecord.ProvidedSymbols).Count -ne 1 -or $mainRecord.ProvidedSymbols[0] -ne "main") {
    Write-Error "Expected main object to provide symbol 'main' by default."
    exit 1
}
if (@($mainRecord.RequiredSymbols).Count -ne 0) {
    Write-Error "Expected main object to have no required symbols by default."
    exit 1
}

$exitCodeWin = [int](& $reader -ObjectPath $objWin -ExpectedTarget x86_64-windows-pe)
if ($exitCodeWin -ne 7) {
    Write-Error ("Expected windows finobj reader exit code 7, got {0}" -f $exitCodeWin)
    exit 1
}

$unitRecord = & $reader -ObjectPath $objUnit -ExpectedTarget x86_64-linux-elf -AsRecord
if ($unitRecord.EntrySymbol -ne "unit") {
    Write-Error ("Expected unit entry symbol, got {0}" -f $unitRecord.EntrySymbol)
    exit 1
}
if ([int]$unitRecord.ExitCode -ne 7) {
    Write-Error ("Expected unit record exit code 7, got {0}" -f $unitRecord.ExitCode)
    exit 1
}
if (@($unitRecord.ProvidedSymbols).Count -ne 0) {
    Write-Error "Expected unit object to provide no symbols by default."
    exit 1
}
if (@($unitRecord.RequiredSymbols).Count -ne 0) {
    Write-Error "Expected unit object to require no symbols by default."
    exit 1
}

$symbolsRecord = & $reader -ObjectPath $objSymbols -ExpectedTarget x86_64-linux-elf -AsRecord
if ((@($symbolsRecord.ProvidedSymbols) -join ",") -ne "main,helper") {
    Write-Error "Expected provided symbols 'main,helper' from custom finobj."
    exit 1
}
if ((@($symbolsRecord.RequiredSymbols) -join ",") -ne "dep_a,dep_b") {
    Write-Error "Expected required symbols 'dep_a,dep_b' from custom finobj."
    exit 1
}

Set-Content -Path $objSymbolsManualOrder -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
provides=helper,main
requires=dep_b,dep_a
"@
$manualOrderRecord = & $reader -ObjectPath $objSymbolsManualOrder -ExpectedTarget x86_64-linux-elf -AsRecord
if ((@($manualOrderRecord.ProvidedSymbols) -join ",") -ne "main,helper") {
    Write-Error "Expected reader canonical provided order 'main,helper' from manual finobj."
    exit 1
}
if ((@($manualOrderRecord.RequiredSymbols) -join ",") -ne "dep_a,dep_b") {
    Write-Error "Expected reader canonical required order 'dep_a,dep_b' from manual finobj."
    exit 1
}

$relocRecord = & $reader -ObjectPath $objRelocs -ExpectedTarget x86_64-linux-elf -AsRecord
$relocKeys = @($relocRecord.Relocations | ForEach-Object { $_.Key })
if (($relocKeys -join ",") -ne "dep_a@16:abs32,dep_b@32:rel32") {
    Write-Error ("Expected relocation keys 'dep_a@16:abs32,dep_b@32:rel32', got '{0}'." -f ($relocKeys -join ","))
    exit 1
}

$badObj = Join-Path $tmpDir "invalid.finobj"
Set-Content -Path $badObj -Value "finobj_format=bad`nfinobj_version=1`nexit_code=0`n"
Assert-ReaderFails -Path $badObj -Label "bad format and missing required keys"

$dupKeyObj = Join-Path $tmpDir "invalid-duplicate-key.finobj"
Set-Content -Path $dupKeyObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
exit_code=9
"@
Assert-ReaderFails -Path $dupKeyObj -Label "duplicate key"

$badTargetObj = Join-Path $tmpDir "invalid-target.finobj"
Set-Content -Path $badTargetObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-riscv-none
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
"@
Assert-ReaderFails -Path $badTargetObj -Label "unsupported target"

$badEntryObj = Join-Path $tmpDir "invalid-entry-symbol.finobj"
Set-Content -Path $badEntryObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=start
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
"@
Assert-ReaderFails -Path $badEntryObj -Label "unsupported entry symbol"

$badSourcePathObj = Join-Path $tmpDir "invalid-source-path.finobj"
Set-Content -Path $badSourcePathObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=C:/absolute/path/main.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
"@
Assert-ReaderFails -Path $badSourcePathObj -Label "absolute source path"

$badSourceHashObj = Join-Path $tmpDir "invalid-source-hash.finobj"
Set-Content -Path $badSourceHashObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1234
"@
Assert-ReaderFails -Path $badSourceHashObj -Label "invalid source hash format"

$badProvidesObj = Join-Path $tmpDir "invalid-provides-symbol.finobj"
Set-Content -Path $badProvidesObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
provides=main,bad-symbol
"@
Assert-ReaderFails -Path $badProvidesObj -Label "invalid provides symbol"

$dupRequiresObj = Join-Path $tmpDir "invalid-requires-duplicate.finobj"
Set-Content -Path $dupRequiresObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
requires=dep,dep
"@
Assert-ReaderFails -Path $dupRequiresObj -Label "duplicate requires symbol"

$overlapObj = Join-Path $tmpDir "invalid-symbol-overlap.finobj"
Set-Content -Path $overlapObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
provides=main,dep
requires=dep
"@
Assert-ReaderFails -Path $overlapObj -Label "provides/requires overlap"

$badRelocObj = Join-Path $tmpDir "invalid-reloc-format.finobj"
Set-Content -Path $badRelocObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
requires=dep
relocs=dep
"@
Assert-ReaderFails -Path $badRelocObj -Label "invalid relocation token"

$badRelocKindObj = Join-Path $tmpDir "invalid-reloc-kind.finobj"
Set-Content -Path $badRelocKindObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
requires=dep
relocs=dep@1:abs64
"@
Assert-ReaderFails -Path $badRelocKindObj -Label "unsupported relocation kind"

$dupRelocObj = Join-Path $tmpDir "invalid-reloc-duplicate.finobj"
Set-Content -Path $dupRelocObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
requires=dep
relocs=dep@1,dep@1
"@
Assert-ReaderFails -Path $dupRelocObj -Label "duplicate relocation entry"

$dupRelocOffsetObj = Join-Path $tmpDir "invalid-reloc-duplicate-offset.finobj"
Set-Content -Path $dupRelocOffsetObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
requires=dep_a,dep_b
relocs=dep_a@1,dep_b@1
"@
Assert-ReaderFails -Path $dupRelocOffsetObj -Label "duplicate relocation offset"

$relocMissingRequiresObj = Join-Path $tmpDir "invalid-reloc-missing-requires.finobj"
Set-Content -Path $relocMissingRequiresObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
requires=dep_a
relocs=dep_b@1
"@
Assert-ReaderFails -Path $relocMissingRequiresObj -Label "relocation symbol not listed in requires"

$relocProvidedObj = Join-Path $tmpDir "invalid-reloc-provided-symbol.finobj"
Set-Content -Path $relocProvidedObj -Value @"
finobj_format=finobj-stage0
finobj_version=1
target=x86_64-linux-elf
entry_symbol=main
exit_code=7
source_path=tests/conformance/fixtures/main_exit7.fn
source_sha256=1111111111111111111111111111111111111111111111111111111111111111
provides=main,helper
requires=dep
relocs=helper@1
"@
Assert-ReaderFails -Path $relocProvidedObj -Label "relocation symbol locally provided"

Write-Host "finobj roundtrip conformance check passed."

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

Write-Host "finobj roundtrip conformance check passed."

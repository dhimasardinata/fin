Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$writer = Join-Path $repoRoot "compiler/finobj/stage0/write_finobj_exit.ps1"
$linker = Join-Path $repoRoot "compiler/finld/stage0/link_finobj_to_elf.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$verifyPe = Join-Path $repoRoot "tests/bootstrap/verify_pe_exit0.ps1"
$runElf = Join-Path $repoRoot "tests/integration/run_linux_elf.ps1"
$runPe = Join-Path $repoRoot "tests/integration/run_windows_pe.ps1"
$tmpDir = Join-Path $repoRoot "artifacts/tmp/finobj-link"

if (Test-Path $tmpDir) {
    Remove-Item -Recurse -Force $tmpDir
}
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

$sourceMain = Join-Path $repoRoot "tests/conformance/fixtures/main_exit_var_assign.fn"
$sourceUnit = Join-Path $repoRoot "tests/conformance/fixtures/main_exit0.fn"
$objLinuxMain = Join-Path $tmpDir "main-linux.finobj"
$objLinuxUnit = Join-Path $tmpDir "unit-linux.finobj"
$objLinuxMain2 = Join-Path $tmpDir "main2-linux.finobj"
$objWindowsMain = Join-Path $tmpDir "main-windows.finobj"
$objWindowsUnit = Join-Path $tmpDir "unit-windows.finobj"
$outLinux = Join-Path $tmpDir "main-linked"
$outWindows = Join-Path $tmpDir "main-linked.exe"
$outBadNoMain = Join-Path $tmpDir "bad-no-main"
$outBadDuplicateMain = Join-Path $tmpDir "bad-duplicate-main"

function Assert-LinkFails {
    param(
        [scriptblock]$Action,
        [string]$Label
    )

    $failed = $false
    try {
        & $Action
    }
    catch {
        $failed = $true
    }

    if (-not $failed) {
        Write-Error ("Expected linker failure: {0}" -f $Label)
        exit 1
    }
}

& $writer -SourcePath $sourceMain -OutFile $objLinuxMain -Target x86_64-linux-elf -EntrySymbol main
& $writer -SourcePath $sourceUnit -OutFile $objLinuxUnit -Target x86_64-linux-elf -EntrySymbol unit
& $writer -SourcePath $sourceUnit -OutFile $objLinuxMain2 -Target x86_64-linux-elf -EntrySymbol main
& $writer -SourcePath $sourceMain -OutFile $objWindowsMain -Target x86_64-windows-pe -EntrySymbol main
& $writer -SourcePath $sourceUnit -OutFile $objWindowsUnit -Target x86_64-windows-pe -EntrySymbol unit

& $linker -ObjectPath @($objLinuxMain, $objLinuxUnit) -OutFile $outLinux -Target x86_64-linux-elf -Verify
& $verifyElf -Path $outLinux -ExpectedExitCode 8
& $runElf -Path $outLinux -ExpectedExitCode 8

& $linker -ObjectPath @($objWindowsMain, $objWindowsUnit) -OutFile $outWindows -Target x86_64-windows-pe -Verify
& $verifyPe -Path $outWindows -ExpectedExitCode 8
& $runPe -Path $outWindows -ExpectedExitCode 8

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objLinuxUnit) -OutFile $outBadNoMain -Target x86_64-linux-elf -Verify | Out-Null
} -Label "no main entry object"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objLinuxMain, $objLinuxMain2) -OutFile $outBadDuplicateMain -Target x86_64-linux-elf -Verify | Out-Null
} -Label "duplicate main entry objects"

Write-Host "finobj link integration check passed."

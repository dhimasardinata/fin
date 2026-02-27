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
$objLinuxMainRequiresHelper = Join-Path $tmpDir "main-requires-helper.finobj"
$objLinuxMainRequiresMissing = Join-Path $tmpDir "main-requires-missing.finobj"
$objLinuxUnitHelper = Join-Path $tmpDir "unit-helper.finobj"
$objLinuxUnitHelper2 = Join-Path $tmpDir "unit-helper-dup.finobj"
$objWindowsMain = Join-Path $tmpDir "main-windows.finobj"
$objWindowsUnit = Join-Path $tmpDir "unit-windows.finobj"
$outLinux = Join-Path $tmpDir "main-linked"
$outLinuxReordered = Join-Path $tmpDir "main-linked-reordered"
$outWindows = Join-Path $tmpDir "main-linked.exe"
$outWindowsReordered = Join-Path $tmpDir "main-linked-reordered.exe"
$outBadNoMain = Join-Path $tmpDir "bad-no-main"
$outBadDuplicateMain = Join-Path $tmpDir "bad-duplicate-main"
$outBadDuplicatePath = Join-Path $tmpDir "bad-duplicate-path"
$outBadDuplicateIdentity = Join-Path $tmpDir "bad-duplicate-identity"
$outBadUnresolvedSymbol = Join-Path $tmpDir "bad-unresolved-symbol"
$outBadDuplicateSymbol = Join-Path $tmpDir "bad-duplicate-symbol"
$outWithResolvedSymbol = Join-Path $tmpDir "ok-resolved-symbol"
$outWithResolvedSymbolReordered = Join-Path $tmpDir "ok-resolved-symbol-reordered"
$objLinuxUnitCopy = Join-Path $tmpDir "unit-linux-copy.finobj"

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

function Assert-SameHash {
    param(
        [string]$PathA,
        [string]$PathB,
        [string]$Label
    )

    $hashA = (Get-FileHash -Path $PathA -Algorithm SHA256).Hash.ToLowerInvariant()
    $hashB = (Get-FileHash -Path $PathB -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hashA -ne $hashB) {
        Write-Error ("Expected matching hashes ({0}): {1} vs {2}" -f $Label, $hashA, $hashB)
        exit 1
    }
}

function Assert-SameValue {
    param(
        [string]$ValueA,
        [string]$ValueB,
        [string]$Label
    )

    if ($ValueA -ne $ValueB) {
        Write-Error ("Expected matching values ({0}): {1} vs {2}" -f $Label, $ValueA, $ValueB)
        exit 1
    }
}

& $writer -SourcePath $sourceMain -OutFile $objLinuxMain -Target x86_64-linux-elf -EntrySymbol main
& $writer -SourcePath $sourceUnit -OutFile $objLinuxUnit -Target x86_64-linux-elf -EntrySymbol unit
& $writer -SourcePath $sourceUnit -OutFile $objLinuxMain2 -Target x86_64-linux-elf -EntrySymbol main
& $writer -SourcePath $sourceMain -OutFile $objLinuxMainRequiresHelper -Target x86_64-linux-elf -EntrySymbol main -Requires helper -Relocs helper@16
& $writer -SourcePath $sourceMain -OutFile $objLinuxMainRequiresMissing -Target x86_64-linux-elf -EntrySymbol main -Requires missing_sym -Relocs missing_sym@16
& $writer -SourcePath $sourceUnit -OutFile $objLinuxUnitHelper -Target x86_64-linux-elf -EntrySymbol unit -Provides helper
& $writer -SourcePath $sourceUnit -OutFile $objLinuxUnitHelper2 -Target x86_64-linux-elf -EntrySymbol unit -Provides helper
& $writer -SourcePath $sourceMain -OutFile $objWindowsMain -Target x86_64-windows-pe -EntrySymbol main
& $writer -SourcePath $sourceUnit -OutFile $objWindowsUnit -Target x86_64-windows-pe -EntrySymbol unit
Copy-Item -Path $objLinuxUnit -Destination $objLinuxUnitCopy -Force

$linuxRecord = & $linker -ObjectPath @($objLinuxMain, $objLinuxUnit) -OutFile $outLinux -Target x86_64-linux-elf -Verify -AsRecord
& $verifyElf -Path $outLinux -ExpectedExitCode 8
& $runElf -Path $outLinux -ExpectedExitCode 8

$linuxRecordReordered = & $linker -ObjectPath @($objLinuxUnit, $objLinuxMain) -OutFile $outLinuxReordered -Target x86_64-linux-elf -Verify -AsRecord
Assert-SameHash -PathA $outLinux -PathB $outLinuxReordered -Label "linux object order"
Assert-SameValue -ValueA $linuxRecord.LinkedObjectSetSha256 -ValueB $linuxRecordReordered.LinkedObjectSetSha256 -Label "linux object-set witness"
Assert-SameValue -ValueA $linuxRecord.LinkedRelocationResolutionSha256 -ValueB $linuxRecordReordered.LinkedRelocationResolutionSha256 -Label "linux relocation-resolution witness"

$windowsRecord = & $linker -ObjectPath @($objWindowsMain, $objWindowsUnit) -OutFile $outWindows -Target x86_64-windows-pe -Verify -AsRecord
& $verifyPe -Path $outWindows -ExpectedExitCode 8
& $runPe -Path $outWindows -ExpectedExitCode 8

$windowsRecordReordered = & $linker -ObjectPath @($objWindowsUnit, $objWindowsMain) -OutFile $outWindowsReordered -Target x86_64-windows-pe -Verify -AsRecord
Assert-SameHash -PathA $outWindows -PathB $outWindowsReordered -Label "windows object order"
Assert-SameValue -ValueA $windowsRecord.LinkedObjectSetSha256 -ValueB $windowsRecordReordered.LinkedObjectSetSha256 -Label "windows object-set witness"
Assert-SameValue -ValueA $windowsRecord.LinkedRelocationResolutionSha256 -ValueB $windowsRecordReordered.LinkedRelocationResolutionSha256 -Label "windows relocation-resolution witness"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objLinuxUnit) -OutFile $outBadNoMain -Target x86_64-linux-elf -Verify | Out-Null
} -Label "no main entry object"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objLinuxMain, $objLinuxMain2) -OutFile $outBadDuplicateMain -Target x86_64-linux-elf -Verify | Out-Null
} -Label "duplicate main entry objects"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objLinuxMain, $objLinuxUnit, $objLinuxUnit) -OutFile $outBadDuplicatePath -Target x86_64-linux-elf -Verify | Out-Null
} -Label "duplicate object path"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objLinuxMain, $objLinuxUnit, $objLinuxUnitCopy) -OutFile $outBadDuplicateIdentity -Target x86_64-linux-elf -Verify | Out-Null
} -Label "duplicate object identity"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objLinuxMainRequiresMissing, $objLinuxUnit) -OutFile $outBadUnresolvedSymbol -Target x86_64-linux-elf -Verify | Out-Null
} -Label "unresolved symbol"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objLinuxMainRequiresHelper, $objLinuxUnitHelper, $objLinuxUnitHelper2) -OutFile $outBadDuplicateSymbol -Target x86_64-linux-elf -Verify | Out-Null
} -Label "duplicate symbol provider"

$resolvedRecord = & $linker -ObjectPath @($objLinuxMainRequiresHelper, $objLinuxUnitHelper) -OutFile $outWithResolvedSymbol -Target x86_64-linux-elf -Verify -AsRecord
& $verifyElf -Path $outWithResolvedSymbol -ExpectedExitCode 8
& $runElf -Path $outWithResolvedSymbol -ExpectedExitCode 8

$resolvedRecordReordered = & $linker -ObjectPath @($objLinuxUnitHelper, $objLinuxMainRequiresHelper) -OutFile $outWithResolvedSymbolReordered -Target x86_64-linux-elf -Verify -AsRecord
Assert-SameHash -PathA $outWithResolvedSymbol -PathB $outWithResolvedSymbolReordered -Label "resolved symbol relocation object order"
Assert-SameValue -ValueA $resolvedRecord.LinkedObjectSetSha256 -ValueB $resolvedRecordReordered.LinkedObjectSetSha256 -Label "resolved symbol object-set witness"
Assert-SameValue -ValueA $resolvedRecord.LinkedRelocationResolutionSha256 -ValueB $resolvedRecordReordered.LinkedRelocationResolutionSha256 -Label "resolved symbol relocation-resolution witness"

Write-Host "finobj link integration check passed."

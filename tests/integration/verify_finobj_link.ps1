Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$writer = Join-Path $repoRoot "compiler/finobj/stage0/write_finobj_exit.ps1"
$linker = Join-Path $repoRoot "compiler/finld/stage0/link_finobj_to_elf.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$verifyPe = Join-Path $repoRoot "tests/bootstrap/verify_pe_exit0.ps1"
$runElf = Join-Path $repoRoot "tests/integration/run_linux_elf.ps1"
$runPe = Join-Path $repoRoot "tests/integration/run_windows_pe.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
$finobjHelpers = Join-Path $repoRoot "tests/common/finobj_output_helpers.ps1"
. $tmpWorkspace
. $finobjHelpers
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "finobj-link-"
$tmpDir = $tmpState.TmpDir

$sourceMain = Join-Path $repoRoot "tests/conformance/fixtures/main_exit_var_assign.fn"
$sourceUnit = Join-Path $repoRoot "tests/conformance/fixtures/main_exit0.fn"
$objLinuxMain = Join-Path $tmpDir "main-linux.finobj"
$objLinuxUnit = Join-Path $tmpDir "unit-linux.finobj"
$objLinuxMain2 = Join-Path $tmpDir "main2-linux.finobj"
$objLinuxMainRequiresHelper = Join-Path $tmpDir "main-requires-helper.finobj"
$objLinuxMainRequiresHelperRel32 = Join-Path $tmpDir "main-requires-helper-rel32.finobj"
$objLinuxMainRequiresHelperBadOffset = Join-Path $tmpDir "main-requires-helper-bad-offset.finobj"
$objLinuxMainRequiresHelperBadSite = Join-Path $tmpDir "main-requires-helper-bad-site.finobj"
$objLinuxMainRequiresMissing = Join-Path $tmpDir "main-requires-missing.finobj"
$objLinuxUnitRelocNonEntry = Join-Path $tmpDir "unit-reloc-nonentry.finobj"
$objLinuxUnitHelper = Join-Path $tmpDir "unit-helper.finobj"
$objLinuxUnitHelper2 = Join-Path $tmpDir "unit-helper-dup.finobj"
$objLinuxUnitHelperValue = Join-Path $tmpDir "unit-helper-value.finobj"
$objWindowsMain = Join-Path $tmpDir "main-windows.finobj"
$objWindowsUnit = Join-Path $tmpDir "unit-windows.finobj"
$objWindowsMainRequiresHelper = Join-Path $tmpDir "main-requires-helper-windows.finobj"
$objWindowsMainRequiresHelperBadOffset = Join-Path $tmpDir "main-requires-helper-windows-bad-offset.finobj"
$objWindowsMainRequiresHelperBadSite = Join-Path $tmpDir "main-requires-helper-windows-bad-site.finobj"
$objWindowsMainRequiresHelperRel32 = Join-Path $tmpDir "main-requires-helper-windows-rel32.finobj"
$objWindowsUnitRelocNonEntry = Join-Path $tmpDir "unit-reloc-nonentry-windows.finobj"
$objWindowsUnitHelper = Join-Path $tmpDir "unit-helper-windows.finobj"
$objWindowsUnitHelperValue = Join-Path $tmpDir "unit-helper-value-windows.finobj"
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
$outBadNonEntryRelocation = Join-Path $tmpDir "bad-non-entry-relocation"
$outBadRelocationBounds = Join-Path $tmpDir "bad-relocation-bounds"
$outBadRelocationSite = Join-Path $tmpDir "bad-relocation-site"
$outBadNonEntryRelocationWindows = Join-Path $tmpDir "bad-non-entry-relocation-windows.exe"
$outBadRelocationBoundsWindows = Join-Path $tmpDir "bad-relocation-bounds-windows.exe"
$outBadRelocationSiteWindows = Join-Path $tmpDir "bad-relocation-site-windows.exe"
$outBadRelocationKindWindows = Join-Path $tmpDir "bad-relocation-kind-windows.exe"
$outWithResolvedSymbol = Join-Path $tmpDir "ok-resolved-symbol"
$outWithResolvedSymbolReordered = Join-Path $tmpDir "ok-resolved-symbol-reordered"
$outWithResolvedSymbolRel32 = Join-Path $tmpDir "ok-resolved-symbol-rel32"
$outWithResolvedSymbolValue = Join-Path $tmpDir "ok-resolved-symbol-value"
$outWithResolvedSymbolWindows = Join-Path $tmpDir "ok-resolved-symbol-windows.exe"
$outWithResolvedSymbolWindowsReordered = Join-Path $tmpDir "ok-resolved-symbol-windows-reordered.exe"
$outWithResolvedSymbolValueWindows = Join-Path $tmpDir "ok-resolved-symbol-value-windows.exe"
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

function Assert-VerifyRecord {
    param(
        [object]$Record,
        [bool]$ExpectedEnabled,
        [string]$ExpectedMode,
        [string]$Label
    )

    if ([bool]$Record.LinkedVerifyEnabled -ne [bool]$ExpectedEnabled) {
        Write-Error ("Expected verify enabled={0} ({1}), found {2}" -f $ExpectedEnabled, $Label, $Record.LinkedVerifyEnabled)
        exit 1
    }
    if ([string]$Record.LinkedVerifyMode -ne [string]$ExpectedMode) {
        Write-Error ("Expected verify mode={0} ({1}), found {2}" -f $ExpectedMode, $Label, $Record.LinkedVerifyMode)
        exit 1
    }
}

& $writer -SourcePath $sourceMain -OutFile $objLinuxMain -Target x86_64-linux-elf -EntrySymbol main
& $writer -SourcePath $sourceUnit -OutFile $objLinuxUnit -Target x86_64-linux-elf -EntrySymbol unit
& $writer -SourcePath $sourceUnit -OutFile $objLinuxMain2 -Target x86_64-linux-elf -EntrySymbol main
& $writer -SourcePath $sourceMain -OutFile $objLinuxMainRequiresHelper -Target x86_64-linux-elf -EntrySymbol main -Requires helper -Relocs helper@6
& $writer -SourcePath $sourceMain -OutFile $objLinuxMainRequiresHelperRel32 -Target x86_64-linux-elf -EntrySymbol main -Requires helper -Relocs helper@6:rel32
& $writer -SourcePath $sourceMain -OutFile $objLinuxMainRequiresHelperBadOffset -Target x86_64-linux-elf -EntrySymbol main -Requires helper -Relocs helper@16
& $writer -SourcePath $sourceMain -OutFile $objLinuxMainRequiresHelperBadSite -Target x86_64-linux-elf -EntrySymbol main -Requires helper -Relocs helper@0
& $writer -SourcePath $sourceMain -OutFile $objLinuxMainRequiresMissing -Target x86_64-linux-elf -EntrySymbol main -Requires missing_sym -Relocs missing_sym@6
& $writer -SourcePath $sourceUnit -OutFile $objLinuxUnitRelocNonEntry -Target x86_64-linux-elf -EntrySymbol unit -Requires main -Relocs main@6
& $writer -SourcePath $sourceMain -OutFile $objLinuxUnitHelper -Target x86_64-linux-elf -EntrySymbol unit -Provides helper
& $writer -SourcePath $sourceMain -OutFile $objLinuxUnitHelper2 -Target x86_64-linux-elf -EntrySymbol unit -Provides helper
& $writer -SourcePath $sourceUnit -OutFile $objLinuxUnitHelperValue -Target x86_64-linux-elf -EntrySymbol unit -Provides helper -ProvideValues helper=42
& $writer -SourcePath $sourceMain -OutFile $objWindowsMain -Target x86_64-windows-pe -EntrySymbol main
& $writer -SourcePath $sourceUnit -OutFile $objWindowsUnit -Target x86_64-windows-pe -EntrySymbol unit
& $writer -SourcePath $sourceMain -OutFile $objWindowsMainRequiresHelper -Target x86_64-windows-pe -EntrySymbol main -Requires helper -Relocs helper@1
& $writer -SourcePath $sourceMain -OutFile $objWindowsMainRequiresHelperBadOffset -Target x86_64-windows-pe -EntrySymbol main -Requires helper -Relocs helper@16
& $writer -SourcePath $sourceMain -OutFile $objWindowsMainRequiresHelperBadSite -Target x86_64-windows-pe -EntrySymbol main -Requires helper -Relocs helper@0
& $writer -SourcePath $sourceMain -OutFile $objWindowsMainRequiresHelperRel32 -Target x86_64-windows-pe -EntrySymbol main -Requires helper -Relocs helper@1:rel32
& $writer -SourcePath $sourceUnit -OutFile $objWindowsUnitRelocNonEntry -Target x86_64-windows-pe -EntrySymbol unit -Requires main -Relocs main@1
& $writer -SourcePath $sourceMain -OutFile $objWindowsUnitHelper -Target x86_64-windows-pe -EntrySymbol unit -Provides helper
& $writer -SourcePath $sourceUnit -OutFile $objWindowsUnitHelperValue -Target x86_64-windows-pe -EntrySymbol unit -Provides helper -ProvideValues helper=42
Copy-Item -Path $objLinuxUnit -Destination $objLinuxUnitCopy -Force

$linuxRecord = & $linker -ObjectPath @($objLinuxMain, $objLinuxUnit) -OutFile $outLinux -Target x86_64-linux-elf -Verify -AsRecord
Assert-VerifyRecord -Record $linuxRecord -ExpectedEnabled $true -ExpectedMode "strict" -Label "linux strict verification"
& $verifyElf -Path $outLinux -ExpectedExitCode 8
& $runElf -Path $outLinux -ExpectedExitCode 8

$linuxRecordReordered = & $linker -ObjectPath @($objLinuxUnit, $objLinuxMain) -OutFile $outLinuxReordered -Target x86_64-linux-elf -Verify -AsRecord
Assert-VerifyRecord -Record $linuxRecordReordered -ExpectedEnabled $true -ExpectedMode "strict" -Label "linux reordered strict verification"
$null = Assert-FileSha256Equal -LeftPath $outLinux -RightPath $outLinuxReordered -Label "linux object order"
Assert-SameValue -ValueA $linuxRecord.LinkedObjectSetSha256 -ValueB $linuxRecordReordered.LinkedObjectSetSha256 -Label "linux object-set witness"
Assert-SameValue -ValueA $linuxRecord.LinkedSymbolResolutionSha256 -ValueB $linuxRecordReordered.LinkedSymbolResolutionSha256 -Label "linux symbol-resolution witness"
Assert-SameValue -ValueA $linuxRecord.LinkedRelocationResolutionSha256 -ValueB $linuxRecordReordered.LinkedRelocationResolutionSha256 -Label "linux relocation-resolution witness"

$windowsRecord = & $linker -ObjectPath @($objWindowsMain, $objWindowsUnit) -OutFile $outWindows -Target x86_64-windows-pe -Verify -AsRecord
Assert-VerifyRecord -Record $windowsRecord -ExpectedEnabled $true -ExpectedMode "strict" -Label "windows strict verification"
& $verifyPe -Path $outWindows -ExpectedExitCode 8
& $runPe -Path $outWindows -ExpectedExitCode 8

$windowsRecordReordered = & $linker -ObjectPath @($objWindowsUnit, $objWindowsMain) -OutFile $outWindowsReordered -Target x86_64-windows-pe -Verify -AsRecord
Assert-VerifyRecord -Record $windowsRecordReordered -ExpectedEnabled $true -ExpectedMode "strict" -Label "windows reordered strict verification"
$null = Assert-FileSha256Equal -LeftPath $outWindows -RightPath $outWindowsReordered -Label "windows object order"
Assert-SameValue -ValueA $windowsRecord.LinkedObjectSetSha256 -ValueB $windowsRecordReordered.LinkedObjectSetSha256 -Label "windows object-set witness"
Assert-SameValue -ValueA $windowsRecord.LinkedSymbolResolutionSha256 -ValueB $windowsRecordReordered.LinkedSymbolResolutionSha256 -Label "windows symbol-resolution witness"
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

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objLinuxMain, $objLinuxUnitRelocNonEntry) -OutFile $outBadNonEntryRelocation -Target x86_64-linux-elf -Verify | Out-Null
} -Label "non-entry relocation materialization not supported in stage0"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objLinuxMainRequiresHelperBadOffset, $objLinuxUnitHelper) -OutFile $outBadRelocationBounds -Target x86_64-linux-elf -Verify | Out-Null
} -Label "relocation offset out of stage0 bounds"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objLinuxMainRequiresHelperBadSite, $objLinuxUnitHelper) -OutFile $outBadRelocationSite -Target x86_64-linux-elf -Verify | Out-Null
} -Label "relocation offset not supported by stage0 code layout"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objWindowsMainRequiresHelperBadOffset, $objWindowsUnitHelper) -OutFile $outBadRelocationBoundsWindows -Target x86_64-windows-pe -Verify | Out-Null
} -Label "windows relocation offset out of stage0 bounds"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objWindowsMainRequiresHelperBadSite, $objWindowsUnitHelper) -OutFile $outBadRelocationSiteWindows -Target x86_64-windows-pe -Verify | Out-Null
} -Label "windows relocation offset not supported by stage0 code layout"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objWindowsMain, $objWindowsUnitRelocNonEntry) -OutFile $outBadNonEntryRelocationWindows -Target x86_64-windows-pe -Verify | Out-Null
} -Label "windows non-entry relocation materialization not supported in stage0"

Assert-LinkFails -Action {
    & $linker -ObjectPath @($objWindowsMainRequiresHelperRel32, $objWindowsUnitHelper) -OutFile $outBadRelocationKindWindows -Target x86_64-windows-pe -Verify | Out-Null
} -Label "windows rel32 relocation kind not supported in stage0"

$resolvedRecord = & $linker -ObjectPath @($objLinuxMainRequiresHelper, $objLinuxUnitHelper) -OutFile $outWithResolvedSymbol -Target x86_64-linux-elf -Verify -AsRecord
Assert-VerifyRecord -Record $resolvedRecord -ExpectedEnabled $true -ExpectedMode "structure_only_relocation_patched" -Label "linux relocation-patched verification"
& $verifyElf -Path $outWithResolvedSymbol -ExpectedExitCode 8
& $runElf -Path $outWithResolvedSymbol -ExpectedExitCode 8

$resolvedRecordReordered = & $linker -ObjectPath @($objLinuxUnitHelper, $objLinuxMainRequiresHelper) -OutFile $outWithResolvedSymbolReordered -Target x86_64-linux-elf -Verify -AsRecord
Assert-VerifyRecord -Record $resolvedRecordReordered -ExpectedEnabled $true -ExpectedMode "structure_only_relocation_patched" -Label "linux reordered relocation-patched verification"
$null = Assert-FileSha256Equal -LeftPath $outWithResolvedSymbol -RightPath $outWithResolvedSymbolReordered -Label "resolved symbol relocation object order"
Assert-SameValue -ValueA $resolvedRecord.LinkedObjectSetSha256 -ValueB $resolvedRecordReordered.LinkedObjectSetSha256 -Label "resolved symbol object-set witness"
Assert-SameValue -ValueA $resolvedRecord.LinkedSymbolResolutionSha256 -ValueB $resolvedRecordReordered.LinkedSymbolResolutionSha256 -Label "resolved symbol symbol-resolution witness"
Assert-SameValue -ValueA $resolvedRecord.LinkedRelocationResolutionSha256 -ValueB $resolvedRecordReordered.LinkedRelocationResolutionSha256 -Label "resolved symbol relocation-resolution witness"

$rel32Record = & $linker -ObjectPath @($objLinuxMainRequiresHelperRel32, $objLinuxUnitHelper) -OutFile $outWithResolvedSymbolRel32 -Target x86_64-linux-elf -AsRecord
Assert-VerifyRecord -Record $rel32Record -ExpectedEnabled $false -ExpectedMode "disabled" -Label "linux rel32 no-verify mode"
& $runElf -Path $outWithResolvedSymbolRel32 -ExpectedExitCode 254
if ($rel32Record.LinkedRelocationsAppliedCount -ne 1) {
    Write-Error ("Expected 1 applied relocation for rel32 case, found {0}" -f $rel32Record.LinkedRelocationsAppliedCount)
    exit 1
}

$symbolValueRecord = & $linker -ObjectPath @($objLinuxMainRequiresHelper, $objLinuxUnitHelperValue) -OutFile $outWithResolvedSymbolValue -Target x86_64-linux-elf -Verify -AsRecord
Assert-VerifyRecord -Record $symbolValueRecord -ExpectedEnabled $true -ExpectedMode "structure_only_relocation_patched" -Label "linux symbol-value relocation-patched verification"
& $runElf -Path $outWithResolvedSymbolValue -ExpectedExitCode 42
if ($symbolValueRecord.LinkedRelocationsAppliedCount -ne 1) {
    Write-Error ("Expected 1 applied relocation for symbol value case, found {0}" -f $symbolValueRecord.LinkedRelocationsAppliedCount)
    exit 1
}
Assert-LinkFails -Action {
    & $verifyElf -Path $outWithResolvedSymbolValue -ExpectedExitCode 8 | Out-Null
} -Label "strict ELF verifier should fail for relocation-patched immediate mismatch"
& $verifyElf -Path $outWithResolvedSymbolValue -ExpectedExitCode 8 -AllowPatchedCode

$windowsResolvedRecord = & $linker -ObjectPath @($objWindowsMainRequiresHelper, $objWindowsUnitHelper) -OutFile $outWithResolvedSymbolWindows -Target x86_64-windows-pe -AsRecord
Assert-VerifyRecord -Record $windowsResolvedRecord -ExpectedEnabled $false -ExpectedMode "disabled" -Label "windows resolved abs32 no-verify mode"
& $verifyPe -Path $outWithResolvedSymbolWindows -ExpectedExitCode 8
& $runPe -Path $outWithResolvedSymbolWindows -ExpectedExitCode 8
if ($windowsResolvedRecord.LinkedRelocationsAppliedCount -ne 1) {
    Write-Error ("Expected 1 applied relocation for windows abs32 case, found {0}" -f $windowsResolvedRecord.LinkedRelocationsAppliedCount)
    exit 1
}

$windowsResolvedRecordReordered = & $linker -ObjectPath @($objWindowsUnitHelper, $objWindowsMainRequiresHelper) -OutFile $outWithResolvedSymbolWindowsReordered -Target x86_64-windows-pe -AsRecord
Assert-VerifyRecord -Record $windowsResolvedRecordReordered -ExpectedEnabled $false -ExpectedMode "disabled" -Label "windows reordered abs32 no-verify mode"
$null = Assert-FileSha256Equal -LeftPath $outWithResolvedSymbolWindows -RightPath $outWithResolvedSymbolWindowsReordered -Label "windows resolved symbol relocation object order"
Assert-SameValue -ValueA $windowsResolvedRecord.LinkedObjectSetSha256 -ValueB $windowsResolvedRecordReordered.LinkedObjectSetSha256 -Label "windows resolved symbol object-set witness"
Assert-SameValue -ValueA $windowsResolvedRecord.LinkedSymbolResolutionSha256 -ValueB $windowsResolvedRecordReordered.LinkedSymbolResolutionSha256 -Label "windows resolved symbol symbol-resolution witness"
Assert-SameValue -ValueA $windowsResolvedRecord.LinkedRelocationResolutionSha256 -ValueB $windowsResolvedRecordReordered.LinkedRelocationResolutionSha256 -Label "windows resolved symbol relocation-resolution witness"

$windowsSymbolValueRecord = & $linker -ObjectPath @($objWindowsMainRequiresHelper, $objWindowsUnitHelperValue) -OutFile $outWithResolvedSymbolValueWindows -Target x86_64-windows-pe -Verify -AsRecord
Assert-VerifyRecord -Record $windowsSymbolValueRecord -ExpectedEnabled $true -ExpectedMode "structure_only_relocation_patched" -Label "windows symbol-value relocation-patched verification"
& $verifyPe -Path $outWithResolvedSymbolValueWindows -ExpectedExitCode 42
& $runPe -Path $outWithResolvedSymbolValueWindows -ExpectedExitCode 42
if ($windowsSymbolValueRecord.LinkedRelocationsAppliedCount -ne 1) {
    Write-Error ("Expected 1 applied relocation for windows symbol value case, found {0}" -f $windowsSymbolValueRecord.LinkedRelocationsAppliedCount)
    exit 1
}
Assert-LinkFails -Action {
    & $verifyPe -Path $outWithResolvedSymbolValueWindows -ExpectedExitCode 8 | Out-Null
} -Label "strict PE verifier should fail for relocation-patched immediate mismatch"
& $verifyPe -Path $outWithResolvedSymbolValueWindows -ExpectedExitCode 8 -AllowPatchedCode

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "finobj link integration check passed."

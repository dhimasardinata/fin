Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$emitExit = Join-Path $repoRoot "compiler/finc/stage0/emit_elf_exit0.ps1"
$emitWriteExit = Join-Path $repoRoot "compiler/finc/stage0/emit_elf_write_exit.ps1"
$writeFinobj = Join-Path $repoRoot "compiler/finobj/stage0/write_finobj_exit.ps1"
$linkFinobj = Join-Path $repoRoot "compiler/finld/stage0/link_finobj_to_elf.ps1"
$tmpDir = Join-Path $repoRoot "artifacts/tmp/repro-smoke"

if (Test-Path $tmpDir) {
    Remove-Item -Recurse -Force $tmpDir
}
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

function Assert-SameHash {
    param(
        [string]$PathA,
        [string]$PathB,
        [string]$Label
    )

    $hashA = (Get-FileHash -Path $PathA -Algorithm SHA256).Hash.ToLowerInvariant()
    $hashB = (Get-FileHash -Path $PathB -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($hashA -ne $hashB) {
        Write-Error ("Reproducibility failure ({0}): hash mismatch {1} vs {2}" -f $Label, $hashA, $hashB)
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
        Write-Error ("Reproducibility failure ({0}): value mismatch {1} vs {2}" -f $Label, $ValueA, $ValueB)
        exit 1
    }
}

# 1) Exit-only emitter determinism.
$exitA = Join-Path $tmpDir "elf-exit-a"
$exitB = Join-Path $tmpDir "elf-exit-b"
& $emitExit -OutFile $exitA -ExitCode 31
& $emitExit -OutFile $exitB -ExitCode 31
Assert-SameHash -PathA $exitA -PathB $exitB -Label "emit_elf_exit0"

# 2) Write+exit emitter determinism.
$writeA = Join-Path $tmpDir "elf-write-a"
$writeB = Join-Path $tmpDir "elf-write-b"
$msg = "repro check"
& $emitWriteExit -OutFile $writeA -Message $msg -ExitCode 12
& $emitWriteExit -OutFile $writeB -Message $msg -ExitCode 12
Assert-SameHash -PathA $writeA -PathB $writeB -Label "emit_elf_write_exit"

# 3) Stage0 build determinism.
$buildA = Join-Path $tmpDir "build-a"
$buildB = Join-Path $tmpDir "build-b"
& $fin build --src tests/conformance/fixtures/main_exit_var_assign.fn --out $buildA
& $fin build --src tests/conformance/fixtures/main_exit_var_assign.fn --out $buildB
Assert-SameHash -PathA $buildA -PathB $buildB -Label "fin build"

# 4) Stage0 build determinism through finobj+finld pipeline.
$buildFinobjA = Join-Path $tmpDir "build-finobj-a"
$buildFinobjB = Join-Path $tmpDir "build-finobj-b"
& $fin build --src tests/conformance/fixtures/main_exit_var_assign.fn --out $buildFinobjA --pipeline finobj
& $fin build --src tests/conformance/fixtures/main_exit_var_assign.fn --out $buildFinobjB --pipeline finobj
Assert-SameHash -PathA $buildFinobjA -PathB $buildFinobjB -Label "fin build --pipeline finobj"

# 5) Stage0 Windows target build determinism.
$buildWinA = Join-Path $tmpDir "build-win-a.exe"
$buildWinB = Join-Path $tmpDir "build-win-b.exe"
& $fin build --src tests/conformance/fixtures/main_exit_var_assign.fn --out $buildWinA --target x86_64-windows-pe
& $fin build --src tests/conformance/fixtures/main_exit_var_assign.fn --out $buildWinB --target x86_64-windows-pe
Assert-SameHash -PathA $buildWinA -PathB $buildWinB -Label "fin build --target x86_64-windows-pe"

# 6) Stage0 Windows target build determinism through finobj+finld pipeline.
$buildWinFinobjA = Join-Path $tmpDir "build-win-finobj-a.exe"
$buildWinFinobjB = Join-Path $tmpDir "build-win-finobj-b.exe"
& $fin build --src tests/conformance/fixtures/main_exit_var_assign.fn --out $buildWinFinobjA --target x86_64-windows-pe --pipeline finobj
& $fin build --src tests/conformance/fixtures/main_exit_var_assign.fn --out $buildWinFinobjB --target x86_64-windows-pe --pipeline finobj
Assert-SameHash -PathA $buildWinFinobjA -PathB $buildWinFinobjB -Label "fin build --target x86_64-windows-pe --pipeline finobj"

# 7) Package publish determinism on fixed inputs.
$project = Join-Path $tmpDir "repro_pkg"
$manifest = Join-Path $project "fin.toml"
$srcDir = Join-Path $project "src"
$outDirA = Join-Path $project "publish-a"
$outDirB = Join-Path $project "publish-b"

& $fin init --dir $project --name repro_pkg
& $fin pkg add serde --version 1.2.3 --manifest $manifest
& $fin pkg publish --manifest $manifest --src $srcDir --out-dir $outDirA
& $fin pkg publish --manifest $manifest --src $srcDir --out-dir $outDirB

$artifactA = Join-Path $outDirA "repro_pkg-0.1.0-dev.fnpkg"
$artifactB = Join-Path $outDirB "repro_pkg-0.1.0-dev.fnpkg"
Assert-SameHash -PathA $artifactA -PathB $artifactB -Label "fin pkg publish"

# 8) finobj writer determinism on fixed source.
$finobjA = Join-Path $tmpDir "main-a.finobj"
$finobjB = Join-Path $tmpDir "main-b.finobj"
$finobjSrc = "tests/conformance/fixtures/main_exit_var_assign.fn"
& $writeFinobj -SourcePath $finobjSrc -OutFile $finobjA
& $writeFinobj -SourcePath $finobjSrc -OutFile $finobjB
Assert-SameHash -PathA $finobjA -PathB $finobjB -Label "write_finobj_exit"

# 9) finld linker determinism on fixed Linux finobj input.
$linkedA = Join-Path $tmpDir "linked-a"
$linkedB = Join-Path $tmpDir "linked-b"
$linkedReordered = Join-Path $tmpDir "linked-reordered"
$finobjUnitLinux = Join-Path $tmpDir "main-unit-linux.finobj"
& $writeFinobj -SourcePath $finobjSrc -OutFile $finobjA -Target x86_64-linux-elf -Requires helper -Relocs helper@6
& $writeFinobj -SourcePath "tests/conformance/fixtures/main_exit0.fn" -OutFile $finobjUnitLinux -Target x86_64-linux-elf -EntrySymbol unit -Provides helper -ProvideValues helper=8
$linkedRecordA = & $linkFinobj -ObjectPath @($finobjA, $finobjUnitLinux) -OutFile $linkedA -Target x86_64-linux-elf -AsRecord
$linkedRecordB = & $linkFinobj -ObjectPath @($finobjA, $finobjUnitLinux) -OutFile $linkedB -Target x86_64-linux-elf -AsRecord
Assert-SameHash -PathA $linkedA -PathB $linkedB -Label "link_finobj_to_elf"
Assert-SameValue -ValueA $linkedRecordA.LinkedObjectSetSha256 -ValueB $linkedRecordB.LinkedObjectSetSha256 -Label "link_finobj_to_elf object-set witness"
Assert-SameValue -ValueA $linkedRecordA.LinkedSymbolResolutionSha256 -ValueB $linkedRecordB.LinkedSymbolResolutionSha256 -Label "link_finobj_to_elf symbol-resolution witness"
Assert-SameValue -ValueA $linkedRecordA.LinkedRelocationResolutionSha256 -ValueB $linkedRecordB.LinkedRelocationResolutionSha256 -Label "link_finobj_to_elf relocation-resolution witness"
Assert-SameValue -ValueA ([string]$linkedRecordA.LinkedRelocationsAppliedCount) -ValueB ([string]$linkedRecordB.LinkedRelocationsAppliedCount) -Label "link_finobj_to_elf applied-relocation count"
$linkedRecordReordered = & $linkFinobj -ObjectPath @($finobjUnitLinux, $finobjA) -OutFile $linkedReordered -Target x86_64-linux-elf -AsRecord
Assert-SameHash -PathA $linkedA -PathB $linkedReordered -Label "link_finobj_to_elf order-independent"
Assert-SameValue -ValueA $linkedRecordA.LinkedObjectSetSha256 -ValueB $linkedRecordReordered.LinkedObjectSetSha256 -Label "link_finobj_to_elf object-set witness order-independent"
Assert-SameValue -ValueA $linkedRecordA.LinkedSymbolResolutionSha256 -ValueB $linkedRecordReordered.LinkedSymbolResolutionSha256 -Label "link_finobj_to_elf symbol-resolution witness order-independent"
Assert-SameValue -ValueA $linkedRecordA.LinkedRelocationResolutionSha256 -ValueB $linkedRecordReordered.LinkedRelocationResolutionSha256 -Label "link_finobj_to_elf relocation-resolution witness order-independent"
Assert-SameValue -ValueA ([string]$linkedRecordA.LinkedRelocationsAppliedCount) -ValueB ([string]$linkedRecordReordered.LinkedRelocationsAppliedCount) -Label "link_finobj_to_elf applied-relocation count order-independent"

# 10) finld linker determinism on fixed Windows finobj input.
$finobjWinA = Join-Path $tmpDir "main-win-a.finobj"
$finobjWinUnit = Join-Path $tmpDir "main-win-unit.finobj"
$linkedWinA = Join-Path $tmpDir "linked-win-a.exe"
$linkedWinB = Join-Path $tmpDir "linked-win-b.exe"
$linkedWinReordered = Join-Path $tmpDir "linked-win-reordered.exe"
& $writeFinobj -SourcePath $finobjSrc -OutFile $finobjWinA -Target x86_64-windows-pe -Requires helper -Relocs helper@1
& $writeFinobj -SourcePath "tests/conformance/fixtures/main_exit0.fn" -OutFile $finobjWinUnit -Target x86_64-windows-pe -EntrySymbol unit -Provides helper -ProvideValues helper=8
$linkedWinRecordA = & $linkFinobj -ObjectPath @($finobjWinA, $finobjWinUnit) -OutFile $linkedWinA -Target x86_64-windows-pe -AsRecord
$linkedWinRecordB = & $linkFinobj -ObjectPath @($finobjWinA, $finobjWinUnit) -OutFile $linkedWinB -Target x86_64-windows-pe -AsRecord
Assert-SameHash -PathA $linkedWinA -PathB $linkedWinB -Label "link_finobj_to_elf --target x86_64-windows-pe"
Assert-SameValue -ValueA $linkedWinRecordA.LinkedObjectSetSha256 -ValueB $linkedWinRecordB.LinkedObjectSetSha256 -Label "link_finobj_to_elf --target x86_64-windows-pe object-set witness"
Assert-SameValue -ValueA $linkedWinRecordA.LinkedSymbolResolutionSha256 -ValueB $linkedWinRecordB.LinkedSymbolResolutionSha256 -Label "link_finobj_to_elf --target x86_64-windows-pe symbol-resolution witness"
Assert-SameValue -ValueA $linkedWinRecordA.LinkedRelocationResolutionSha256 -ValueB $linkedWinRecordB.LinkedRelocationResolutionSha256 -Label "link_finobj_to_elf --target x86_64-windows-pe relocation-resolution witness"
Assert-SameValue -ValueA ([string]$linkedWinRecordA.LinkedRelocationsAppliedCount) -ValueB ([string]$linkedWinRecordB.LinkedRelocationsAppliedCount) -Label "link_finobj_to_elf --target x86_64-windows-pe applied-relocation count"
$linkedWinRecordReordered = & $linkFinobj -ObjectPath @($finobjWinUnit, $finobjWinA) -OutFile $linkedWinReordered -Target x86_64-windows-pe -AsRecord
Assert-SameHash -PathA $linkedWinA -PathB $linkedWinReordered -Label "link_finobj_to_elf --target x86_64-windows-pe order-independent"
Assert-SameValue -ValueA $linkedWinRecordA.LinkedObjectSetSha256 -ValueB $linkedWinRecordReordered.LinkedObjectSetSha256 -Label "link_finobj_to_elf --target x86_64-windows-pe object-set witness order-independent"
Assert-SameValue -ValueA $linkedWinRecordA.LinkedSymbolResolutionSha256 -ValueB $linkedWinRecordReordered.LinkedSymbolResolutionSha256 -Label "link_finobj_to_elf --target x86_64-windows-pe symbol-resolution witness order-independent"
Assert-SameValue -ValueA $linkedWinRecordA.LinkedRelocationResolutionSha256 -ValueB $linkedWinRecordReordered.LinkedRelocationResolutionSha256 -Label "link_finobj_to_elf --target x86_64-windows-pe relocation-resolution witness order-independent"
Assert-SameValue -ValueA ([string]$linkedWinRecordA.LinkedRelocationsAppliedCount) -ValueB ([string]$linkedWinRecordReordered.LinkedRelocationsAppliedCount) -Label "link_finobj_to_elf --target x86_64-windows-pe applied-relocation count order-independent"

Write-Host "stage0 reproducibility check passed."

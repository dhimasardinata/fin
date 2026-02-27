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

# 5) Package publish determinism on fixed inputs.
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

# 6) finobj writer determinism on fixed source.
$finobjA = Join-Path $tmpDir "main-a.finobj"
$finobjB = Join-Path $tmpDir "main-b.finobj"
$finobjSrc = "tests/conformance/fixtures/main_exit_var_assign.fn"
& $writeFinobj -SourcePath $finobjSrc -OutFile $finobjA
& $writeFinobj -SourcePath $finobjSrc -OutFile $finobjB
Assert-SameHash -PathA $finobjA -PathB $finobjB -Label "write_finobj_exit"

# 7) finld linker determinism on fixed finobj input.
$linkedA = Join-Path $tmpDir "linked-a"
$linkedB = Join-Path $tmpDir "linked-b"
& $linkFinobj -ObjectPath $finobjA -OutFile $linkedA
& $linkFinobj -ObjectPath $finobjA -OutFile $linkedB
Assert-SameHash -PathA $linkedA -PathB $linkedB -Label "link_finobj_to_elf"

Write-Host "stage0 reproducibility check passed."

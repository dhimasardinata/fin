param(
    [string]$Source = "src/main.fn",
    [string]$OutFile = "artifacts/main",
    [ValidateSet("direct", "finobj")]
    [string]$Pipeline = "direct",
    [switch]$Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\\..\\..")

$sourcePath = if ([System.IO.Path]::IsPathRooted($Source)) { $Source } else { Join-Path $repoRoot $Source }
$outPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $repoRoot $OutFile }

if (-not (Test-Path $sourcePath)) {
    throw "Source file not found: $sourcePath"
}

$outDir = Split-Path -Parent $outPath
if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

[int]$exitCode = 0
if ($Pipeline -eq "direct") {
    $exitCode = & (Join-Path $scriptDir "parse_main_exit.ps1") -SourcePath $sourcePath
    & (Join-Path $scriptDir "emit_elf_exit0.ps1") -OutFile $outPath -ExitCode $exitCode

    if ($Verify) {
        & (Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1") -Path $outPath -ExpectedExitCode $exitCode
    }
}
else {
    $writeFinobj = Join-Path $repoRoot "compiler/finobj/stage0/write_finobj_exit.ps1"
    $readFinobj = Join-Path $repoRoot "compiler/finobj/stage0/read_finobj_exit.ps1"
    $linkFinobj = Join-Path $repoRoot "compiler/finld/stage0/link_finobj_to_elf.ps1"
    $tmpDir = Join-Path $repoRoot "artifacts/tmp/build-stage0"
    if (-not (Test-Path $tmpDir)) {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    }

    $outName = [System.IO.Path]::GetFileName($outPath)
    if ([string]::IsNullOrWhiteSpace($outName)) {
        throw "Unable to derive output file name from: $outPath"
    }
    $objPath = Join-Path $tmpDir ("{0}.finobj" -f $outName)

    & $writeFinobj -SourcePath $sourcePath -OutFile $objPath
    $exitCode = [int](& $readFinobj -ObjectPath $objPath)
    if ($Verify) {
        & $linkFinobj -ObjectPath $objPath -OutFile $outPath -Verify
    }
    else {
        & $linkFinobj -ObjectPath $objPath -OutFile $outPath
    }
}

Write-Host ("built_source={0}" -f (Resolve-Path $sourcePath))
Write-Host ("built_output={0}" -f (Resolve-Path $outPath))
Write-Host ("program_exit_code={0}" -f $exitCode)

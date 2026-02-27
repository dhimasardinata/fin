param(
    [string]$Source = "src/main.fn",
    [string]$OutFile = "artifacts/main",
    [switch]$Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\\..\\..")

$sourcePath = if ([System.IO.Path]::IsPathRooted($Source)) { $Source } else { Join-Path $repoRoot $Source }
$outPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $repoRoot $OutFile }

$exitCode = & (Join-Path $scriptDir "parse_main_exit.ps1") -SourcePath $sourcePath
& (Join-Path $scriptDir "emit_elf_exit0.ps1") -OutFile $outPath -ExitCode $exitCode

if ($Verify) {
    & (Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1") -Path $outPath -ExpectedExitCode $exitCode
}

Write-Host ("built_source={0}" -f (Resolve-Path $sourcePath))
Write-Host ("built_output={0}" -f (Resolve-Path $outPath))
Write-Host ("program_exit_code={0}" -f $exitCode)

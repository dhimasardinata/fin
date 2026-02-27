param(
    [string]$ObjectPath = "artifacts/main.finobj",
    [string]$OutFile = "artifacts/main-linked",
    [ValidateSet("x86_64-linux-elf", "x86_64-windows-pe")]
    [string]$Target = "x86_64-linux-elf",
    [switch]$Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..\\..")
$reader = Join-Path $repoRoot "compiler/finobj/stage0/read_finobj_exit.ps1"
$emitElf = Join-Path $repoRoot "compiler/finc/stage0/emit_elf_exit0.ps1"
$emitPe = Join-Path $repoRoot "compiler/finc/stage0/emit_pe_exit0.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$verifyPe = Join-Path $repoRoot "tests/bootstrap/verify_pe_exit0.ps1"

$objFull = if ([System.IO.Path]::IsPathRooted($ObjectPath)) {
    [System.IO.Path]::GetFullPath($ObjectPath)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $ObjectPath))
}

$outFull = if ([System.IO.Path]::IsPathRooted($OutFile)) {
    [System.IO.Path]::GetFullPath($OutFile)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutFile))
}

[int]$exitCode = [int](& $reader -ObjectPath $objFull -ExpectedTarget $Target)
if ($Target -eq "x86_64-linux-elf") {
    & $emitElf -OutFile $outFull -ExitCode $exitCode
}
elseif ($Target -eq "x86_64-windows-pe") {
    & $emitPe -OutFile $outFull -ExitCode $exitCode
}
else {
    throw "Unsupported target: $Target"
}

if ($Verify) {
    if ($Target -eq "x86_64-linux-elf") {
        & $verifyElf -Path $outFull -ExpectedExitCode $exitCode
    }
    else {
        & $verifyPe -Path $outFull -ExpectedExitCode $exitCode
    }
}

Write-Host ("linked_object={0}" -f $objFull)
Write-Host ("linked_output={0}" -f $outFull)
Write-Host ("linked_target={0}" -f $Target)
Write-Host ("program_exit_code={0}" -f $exitCode)

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

$source = Join-Path $repoRoot "tests/conformance/fixtures/main_exit_var_assign.fn"
$objLinux = Join-Path $tmpDir "main-linux.finobj"
$objWindows = Join-Path $tmpDir "main-windows.finobj"
$outLinux = Join-Path $tmpDir "main-linked"
$outWindows = Join-Path $tmpDir "main-linked.exe"

& $writer -SourcePath $source -OutFile $objLinux -Target x86_64-linux-elf
& $writer -SourcePath $source -OutFile $objWindows -Target x86_64-windows-pe

& $linker -ObjectPath $objLinux -OutFile $outLinux -Target x86_64-linux-elf -Verify
& $verifyElf -Path $outLinux -ExpectedExitCode 8
& $runElf -Path $outLinux -ExpectedExitCode 8

& $linker -ObjectPath $objWindows -OutFile $outWindows -Target x86_64-windows-pe -Verify
& $verifyPe -Path $outWindows -ExpectedExitCode 8
& $runPe -Path $outWindows -ExpectedExitCode 8

Write-Host "finobj link integration check passed."

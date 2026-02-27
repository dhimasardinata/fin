Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$writer = Join-Path $repoRoot "compiler/finobj/stage0/write_finobj_exit.ps1"
$linker = Join-Path $repoRoot "compiler/finld/stage0/link_finobj_to_elf.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$runElf = Join-Path $repoRoot "tests/integration/run_linux_elf.ps1"
$tmpDir = Join-Path $repoRoot "artifacts/tmp/finobj-link"

if (Test-Path $tmpDir) {
    Remove-Item -Recurse -Force $tmpDir
}
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

$source = Join-Path $repoRoot "tests/conformance/fixtures/main_exit_var_assign.fn"
$obj = Join-Path $tmpDir "main.finobj"
$out = Join-Path $tmpDir "main-linked"

& $writer -SourcePath $source -OutFile $obj
& $linker -ObjectPath $obj -OutFile $out -Verify
& $verifyElf -Path $out -ExpectedExitCode 8
& $runElf -Path $out -ExpectedExitCode 8

Write-Host "finobj link integration check passed."

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$contractPath = Join-Path $repoRoot "docs/stdlib-v0.md"
$fipPath = Join-Path $repoRoot "fips/FIP-0017-lean-stdlib-v0-no-libc.md"
$linuxRuntimePath = Join-Path $repoRoot "runtime/linux_x86_64/syscall-table.md"
$windowsRuntimePath = Join-Path $repoRoot "runtime/windows_x64/syscall-table.md"
$suitePath = Join-Path $repoRoot "tests/run_stage0_suite.ps1"

function Fail-StdlibContract {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

foreach ($path in @($contractPath, $fipPath, $linuxRuntimePath, $windowsRuntimePath, $suitePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        Fail-StdlibContract ("required stdlib contract file is missing: {0}" -f $path)
    }
}

$contract = Get-Content -Path $contractPath -Raw
$fip = Get-Content -Path $fipPath -Raw
$linuxRuntime = Get-Content -Path $linuxRuntimePath -Raw
$windowsRuntime = Get-Content -Path $windowsRuntimePath -Raw
$suite = Get-Content -Path $suitePath -Raw

foreach ($needle in @(
        "std.proc.exit(code: u8)",
        "std.io.write_stdout(bytes)",
        "no dependency on libc",
        "compiler/finc/stage0/emit_elf_exit0.ps1",
        "compiler/finc/stage0/emit_elf_write_exit.ps1",
        "compiler/finc/stage0/emit_pe_exit0.ps1",
        'Before `FIP-0017` can move to `Implemented`'
    )) {
    if ($contract -notmatch [regex]::Escape($needle)) {
        Fail-StdlibContract ("stdlib contract missing required text: {0}" -f $needle)
    }
}

foreach ($needle in @(
        "docs/stdlib-v0.md",
        "tests/reproducibility/verify_stdlib_contract.ps1",
        "runtime/linux_x86_64/syscall-table.md",
        "runtime/windows_x64/syscall-table.md"
    )) {
    if ($fip -notmatch [regex]::Escape($needle)) {
        Fail-StdlibContract ("FIP-0017 implementation list missing: {0}" -f $needle)
    }
}

foreach ($needle in @('`sys_write`', '`sys_exit`')) {
    if ($linuxRuntime -notmatch [regex]::Escape($needle)) {
        Fail-StdlibContract ("Linux runtime table missing stdlib ABI dependency: {0}" -f $needle)
    }
}

foreach ($needle in @("No import table", 'returning value in `eax`')) {
    if ($windowsRuntime -notmatch [regex]::Escape($needle)) {
        Fail-StdlibContract ("Windows runtime contract missing stdlib ABI dependency: {0}" -f $needle)
    }
}

if ($suite -notmatch [regex]::Escape("tests/reproducibility/verify_stdlib_contract.ps1")) {
    Fail-StdlibContract "stage0 suite must run the stdlib contract verifier"
}

Write-Host "stdlib contract check passed."

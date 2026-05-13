param(
    [string]$ContractPath = "",
    [string]$FipPath = "",
    [string]$LinuxRuntimePath = "",
    [string]$WindowsRuntimePath = "",
    [string]$SuitePath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path

function Resolve-StdlibContractPath {
    param(
        [string]$Value,
        [string]$DefaultRelativePath
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return (Join-Path $repoRoot $DefaultRelativePath)
    }

    if ([System.IO.Path]::IsPathRooted($Value)) {
        return $Value
    }

    return (Join-Path $repoRoot $Value)
}

$ContractPath = Resolve-StdlibContractPath -Value $ContractPath -DefaultRelativePath "docs/stdlib-v0.md"
$FipPath = Resolve-StdlibContractPath -Value $FipPath -DefaultRelativePath "fips/FIP-0017-lean-stdlib-v0-no-libc.md"
$LinuxRuntimePath = Resolve-StdlibContractPath -Value $LinuxRuntimePath -DefaultRelativePath "runtime/linux_x86_64/syscall-table.md"
$WindowsRuntimePath = Resolve-StdlibContractPath -Value $WindowsRuntimePath -DefaultRelativePath "runtime/windows_x64/syscall-table.md"
$SuitePath = Resolve-StdlibContractPath -Value $SuitePath -DefaultRelativePath "tests/run_stage0_suite.ps1"

function Fail-StdlibContract {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

foreach ($path in @($ContractPath, $FipPath, $LinuxRuntimePath, $WindowsRuntimePath, $SuitePath)) {
    if (-not (Test-Path -LiteralPath $path)) {
        Fail-StdlibContract ("required stdlib contract file is missing: {0}" -f $path)
    }
}

$contract = Get-Content -Path $ContractPath -Raw
$fip = Get-Content -Path $FipPath -Raw
$linuxRuntime = Get-Content -Path $LinuxRuntimePath -Raw
$windowsRuntime = Get-Content -Path $WindowsRuntimePath -Raw
$suite = Get-Content -Path $SuitePath -Raw

foreach ($needle in @(
        "std.proc.exit(code: u8)",
        "std.io.write_stdout(bytes)",
        "no dependency on libc",
        "compiler/finc/stage0/emit_elf_exit0.ps1",
        "compiler/finc/stage0/emit_elf_write_exit.ps1",
        "compiler/finc/stage0/emit_pe_exit0.ps1",
        'Before `FIP-0017` can move to `Implemented`'
    )) {
    if ($contract -cnotmatch [regex]::Escape($needle)) {
        Fail-StdlibContract ("stdlib contract missing required text: {0}" -f $needle)
    }
}

foreach ($needle in @(
        "docs/stdlib-v0.md",
        "tests/reproducibility/verify_stdlib_contract.ps1",
        "runtime/linux_x86_64/syscall-table.md",
        "runtime/windows_x64/syscall-table.md"
    )) {
    if ($fip -cnotmatch [regex]::Escape($needle)) {
        Fail-StdlibContract ("FIP-0017 implementation list missing: {0}" -f $needle)
    }
}

foreach ($needle in @('`sys_write`', '`sys_exit`')) {
    if ($linuxRuntime -cnotmatch [regex]::Escape($needle)) {
        Fail-StdlibContract ("Linux runtime table missing stdlib ABI dependency: {0}" -f $needle)
    }
}

foreach ($needle in @("No import table", 'returning value in `eax`')) {
    if ($windowsRuntime -cnotmatch [regex]::Escape($needle)) {
        Fail-StdlibContract ("Windows runtime contract missing stdlib ABI dependency: {0}" -f $needle)
    }
}

if ($suite -cnotmatch [regex]::Escape("tests/reproducibility/verify_stdlib_contract.ps1")) {
    Fail-StdlibContract "stage0 suite must run the stdlib contract verifier"
}

Write-Host "stdlib contract check passed."

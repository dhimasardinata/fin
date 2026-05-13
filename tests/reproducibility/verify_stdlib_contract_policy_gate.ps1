Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$policy = Join-Path $repoRoot "tests/reproducibility/verify_stdlib_contract.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace

$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "stdlib-contract-policy-gate-"
$tmpRoot = $tmpState.TmpDir
$tmpContractPath = Join-Path $tmpRoot "docs/stdlib-v0.md"
$tmpFipPath = Join-Path $tmpRoot "fips/FIP-0017-lean-stdlib-v0-no-libc.md"
$tmpLinuxRuntimePath = Join-Path $tmpRoot "runtime/linux_x86_64/syscall-table.md"
$tmpWindowsRuntimePath = Join-Path $tmpRoot "runtime/windows_x64/syscall-table.md"
$tmpSuitePath = Join-Path $tmpRoot "tests/run_stage0_suite.ps1"
$pwsh = (Get-Process -Id $PID).Path

function Copy-ContractFixture {
    foreach ($path in @($tmpContractPath, $tmpFipPath, $tmpLinuxRuntimePath, $tmpWindowsRuntimePath, $tmpSuitePath)) {
        $parent = Split-Path -Parent $path
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Copy-Item -LiteralPath (Join-Path $repoRoot "docs/stdlib-v0.md") -Destination $tmpContractPath -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot "fips/FIP-0017-lean-stdlib-v0-no-libc.md") -Destination $tmpFipPath -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot "runtime/linux_x86_64/syscall-table.md") -Destination $tmpLinuxRuntimePath -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot "runtime/windows_x64/syscall-table.md") -Destination $tmpWindowsRuntimePath -Force
    Copy-Item -LiteralPath (Join-Path $repoRoot "tests/run_stage0_suite.ps1") -Destination $tmpSuitePath -Force
}

function Replace-FileText {
    param(
        [string]$Path,
        [string]$OldValue,
        [string]$NewValue
    )

    $text = Get-Content -LiteralPath $Path -Raw
    if ($text -cnotmatch [regex]::Escape($OldValue)) {
        throw ("fixture missing expected text: {0}" -f $OldValue)
    }

    Set-Content -Path $Path -Value ($text -creplace [regex]::Escape($OldValue), $NewValue) -NoNewline
}

function Invoke-StdlibPolicy {
    & $pwsh `
        -NoLogo `
        -NoProfile `
        -File $policy `
        -ContractPath $tmpContractPath `
        -FipPath $tmpFipPath `
        -LinuxRuntimePath $tmpLinuxRuntimePath `
        -WindowsRuntimePath $tmpWindowsRuntimePath `
        -SuitePath $tmpSuitePath `
        *>&1 | Out-Null
    return $LASTEXITCODE
}

function Assert-Passes {
    param([string]$Label)

    $exitCode = Invoke-StdlibPolicy
    if ($exitCode -ne 0) {
        Write-Error ("Expected stdlib contract policy pass: {0}" -f $Label)
        exit 1
    }
}

function Assert-Fails {
    param([string]$Label)

    $exitCode = Invoke-StdlibPolicy
    if ($exitCode -eq 0) {
        Write-Error ("Expected stdlib contract policy failure: {0}" -f $Label)
        exit 1
    }
}

try {
    Copy-ContractFixture
    Assert-Passes -Label "valid copied stdlib contract"

    Copy-ContractFixture
    Replace-FileText -Path $tmpContractPath -OldValue "compiler/finc/stage0/emit_elf_exit0.ps1" -NewValue "Compiler/finc/stage0/emit_elf_exit0.ps1"
    Assert-Fails -Label "wrong-case ABI witness path in stdlib contract"

    Copy-ContractFixture
    Replace-FileText -Path $tmpFipPath -OldValue "tests/reproducibility/verify_stdlib_contract.ps1" -NewValue "tests/reproducibility/VERIFY_STDLIB_CONTRACT.ps1"
    Assert-Fails -Label "wrong-case FIP implementation path"

    Copy-ContractFixture
    Replace-FileText -Path $tmpLinuxRuntimePath -OldValue '`sys_write`' -NewValue '`SYS_WRITE`'
    Assert-Fails -Label "wrong-case Linux ABI witness"

    Copy-ContractFixture
    Replace-FileText -Path $tmpWindowsRuntimePath -OldValue 'returning value in `eax`' -NewValue 'returning value in `EAX`'
    Assert-Fails -Label "wrong-case Windows ABI witness"

    Copy-ContractFixture
    Replace-FileText -Path $tmpSuitePath -OldValue "tests/reproducibility/verify_stdlib_contract.ps1" -NewValue "tests/reproducibility/Verify_Stdlib_Contract.ps1"
    Assert-Fails -Label "wrong-case stage0 suite verifier path"
}
finally {
    Finalize-TestTmpWorkspace -State $tmpState
}

Write-Host "stdlib contract policy gate self-check passed."

param(
    [switch]$Quick,
    [switch]$SkipDoctor,
    [switch]$SkipRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$emit = Join-Path $repoRoot "compiler/finc/stage0/emit_elf_exit0.ps1"
$emitPe = Join-Path $repoRoot "compiler/finc/stage0/emit_pe_exit0.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$verifyPe = Join-Path $repoRoot "tests/bootstrap/verify_pe_exit0.ps1"
$verifyClosure = Join-Path $repoRoot "tests/bootstrap/verify_stage0_closure.ps1"
$verifyGrammar = Join-Path $repoRoot "tests/conformance/verify_stage0_grammar.ps1"
$verifyFinobjRoundtrip = Join-Path $repoRoot "tests/conformance/verify_finobj_roundtrip.ps1"
$verifyInit = Join-Path $repoRoot "tests/integration/verify_init.ps1"
$verifyFmt = Join-Path $repoRoot "tests/integration/verify_fmt.ps1"
$verifyDoc = Join-Path $repoRoot "tests/integration/verify_doc.ps1"
$verifyPkg = Join-Path $repoRoot "tests/integration/verify_pkg.ps1"
$verifyPkgPublish = Join-Path $repoRoot "tests/integration/verify_pkg_publish.ps1"
$verifyLinuxWriteExit = Join-Path $repoRoot "tests/integration/verify_linux_write_exit.ps1"
$verifyWindowsPeExit = Join-Path $repoRoot "tests/integration/verify_windows_pe_exit.ps1"
$verifyBuildTargetWindows = Join-Path $repoRoot "tests/integration/verify_build_target_windows.ps1"
$verifyManifestTargetResolution = Join-Path $repoRoot "tests/integration/verify_manifest_target_resolution.ps1"
$verifyFinobjLink = Join-Path $repoRoot "tests/integration/verify_finobj_link.ps1"
$verifyBuildPipelineFinobj = Join-Path $repoRoot "tests/integration/verify_build_pipeline_finobj.ps1"
$verifyRepro = Join-Path $repoRoot "tests/reproducibility/verify_stage0_reproducibility.ps1"
$verifyTmpWorkspacePolicy = Join-Path $repoRoot "tests/reproducibility/verify_test_tmp_workspace_policy.ps1"
$verifyManifestPolicyGate = Join-Path $repoRoot "tests/reproducibility/verify_manifest_policy_gate.ps1"
$verifyPolicyGate = Join-Path $repoRoot "tests/reproducibility/verify_toolchain_policy_gate.ps1"

Write-Host "fin test: stage0 suite starting"

if (-not $SkipDoctor) {
    & $fin doctor
}

& $emit -OutFile (Join-Path $repoRoot "artifacts/fin-elf-exit0") -ExitCode 0
& $verifyElf -Path (Join-Path $repoRoot "artifacts/fin-elf-exit0") -ExpectedExitCode 0
& $emitPe -OutFile (Join-Path $repoRoot "artifacts/fin-pe-exit0.exe") -ExitCode 0
& $verifyPe -Path (Join-Path $repoRoot "artifacts/fin-pe-exit0.exe") -ExpectedExitCode 0
& $verifyClosure -VerifyBaseline

& $verifyGrammar
& $verifyFinobjRoundtrip
& $verifyInit
& $verifyFmt
& $verifyDoc
& $verifyPkg
& $verifyPkgPublish
& $verifyLinuxWriteExit
& $verifyWindowsPeExit
& $verifyBuildTargetWindows
& $verifyManifestTargetResolution
& $verifyFinobjLink
& $verifyBuildPipelineFinobj
& $verifyRepro
& $verifyTmpWorkspacePolicy
& $verifyManifestPolicyGate
& $verifyPolicyGate

& $fin build --src tests/conformance/fixtures/main_exit0.fn --out artifacts/test-exit0
& $fin build --src tests/conformance/fixtures/main_exit7.fn --out artifacts/test-exit7
& $fin build --src tests/conformance/fixtures/main_exit_var_assign.fn --out artifacts/test-exit8
& $fin build --src tests/conformance/fixtures/main_exit_typed_u8.fn --out artifacts/test-exit9
& $fin build --src tests/conformance/fixtures/main_exit_signature_u8.fn --out artifacts/test-exit10
& $fin build --src tests/conformance/fixtures/main_exit_try_literal.fn --out artifacts/test-exit11
& $fin build --src tests/conformance/fixtures/main_exit_try_identifier.fn --out artifacts/test-exit12
& $fin build --src tests/conformance/fixtures/main_exit_try_ok_result.fn --out artifacts/test-exit13
& $fin build --src tests/conformance/fixtures/main_exit_result_typed_binding.fn --out artifacts/test-exit14
& $fin build --src tests/conformance/fixtures/main_drop_unused.fn --out artifacts/test-exit15
& $fin build --src tests/conformance/fixtures/main_move_binding.fn --out artifacts/test-exit16
& $fin build --src tests/conformance/fixtures/main_move_reinit_var.fn --out artifacts/test-exit17
& $fin build --src tests/conformance/fixtures/main_drop_reinit_var.fn --out artifacts/test-exit18

if (-not $SkipRun) {
    & $fin run --no-build --out artifacts/test-exit0 --expect-exit 0
    if (-not $Quick) {
        & $fin run --no-build --out artifacts/test-exit7 --expect-exit 7
        & $fin run --no-build --out artifacts/test-exit8 --expect-exit 8
        & $fin run --no-build --out artifacts/test-exit9 --expect-exit 9
        & $fin run --no-build --out artifacts/test-exit10 --expect-exit 10
        & $fin run --no-build --out artifacts/test-exit11 --expect-exit 11
        & $fin run --no-build --out artifacts/test-exit12 --expect-exit 12
        & $fin run --no-build --out artifacts/test-exit13 --expect-exit 13
        & $fin run --no-build --out artifacts/test-exit14 --expect-exit 14
        & $fin run --no-build --out artifacts/test-exit15 --expect-exit 15
        & $fin run --no-build --out artifacts/test-exit16 --expect-exit 16
        & $fin run --no-build --out artifacts/test-exit17 --expect-exit 17
        & $fin run --no-build --out artifacts/test-exit18 --expect-exit 18
    }
}

Write-Host "fin test: stage0 suite passed"

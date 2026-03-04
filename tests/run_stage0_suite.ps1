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
$verifyClosureWorkspacePolicy = Join-Path $repoRoot "tests/reproducibility/verify_closure_workspace_policy.ps1"
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
& $verifyClosureWorkspacePolicy
& $verifyManifestPolicyGate
& $verifyPolicyGate

& $fin build --src tests/conformance/fixtures/main_exit0.fn --out artifacts/test-exit0
& $fin build --src tests/conformance/fixtures/main_exit7.fn --out artifacts/test-exit7
& $fin build --src tests/conformance/fixtures/main_exit_var_assign.fn --out artifacts/test-exit8
& $fin build --src tests/conformance/fixtures/main_exit_typed_u8.fn --out artifacts/test-exit9
& $fin build --src tests/conformance/fixtures/main_exit_signature_u8.fn --out artifacts/test-exit10
& $fin build --src tests/conformance/fixtures/main_exit_add_literals.fn --out artifacts/test-exit21
& $fin build --src tests/conformance/fixtures/main_exit_add_identifier_literal.fn --out artifacts/test-exit42
& $fin build --src tests/conformance/fixtures/main_exit_sub_literals.fn --out artifacts/test-exit57
& $fin build --src tests/conformance/fixtures/main_exit_mul_literals.fn --out artifacts/test-exit63
& $fin build --src tests/conformance/fixtures/main_exit_div_literals.fn --out artifacts/test-exit66
& $fin build --src tests/conformance/fixtures/main_exit_mul_precedence.fn --out artifacts/test-exit65
& $fin build --src tests/conformance/fixtures/main_exit_mul_grouped.fn --out artifacts/test-exit80
& $fin build --src tests/conformance/fixtures/main_exit_cmp_eq_true.fn --out artifacts/test-exit82
& $fin build --src tests/conformance/fixtures/main_exit_cmp_lt_true.fn --out artifacts/test-exit83
& $fin build --src tests/conformance/fixtures/main_exit_cmp_precedence.fn --out artifacts/test-exit86
& $fin build --src tests/conformance/fixtures/main_exit_cmp_ge_false_bias.fn --out artifacts/test-exit90
& $fin build --src tests/conformance/fixtures/main_exit_if_true_literal.fn --out artifacts/test-exit91
& $fin build --src tests/conformance/fixtures/main_exit_if_false_literal.fn --out artifacts/test-exit92
& $fin build --src tests/conformance/fixtures/main_exit_if_cmp_condition.fn --out artifacts/test-exit93
& $fin build --src tests/conformance/fixtures/main_exit_if_move_then_selected.fn --out artifacts/test-exit94
& $fin build --src tests/conformance/fixtures/main_exit_if_move_else_selected.fn --out artifacts/test-exit95
& $fin build --src tests/conformance/fixtures/main_exit_if_result_branches_try.fn --out artifacts/test-exit96
& $fin build --src tests/conformance/fixtures/main_exit_logic_and_true.fn --out artifacts/test-exit97
& $fin build --src tests/conformance/fixtures/main_exit_logic_or_true.fn --out artifacts/test-exit98
& $fin build --src tests/conformance/fixtures/main_exit_logic_precedence.fn --out artifacts/test-exit99
& $fin build --src tests/conformance/fixtures/main_exit_logic_and_short_circuit_move_rhs.fn --out artifacts/test-exit100
& $fin build --src tests/conformance/fixtures/main_exit_logic_or_short_circuit_move_rhs.fn --out artifacts/test-exit101
& $fin build --src tests/conformance/fixtures/main_exit_logic_not_true.fn --out artifacts/test-exit102
& $fin build --src tests/conformance/fixtures/main_exit_logic_not_false.fn --out artifacts/test-exit103
& $fin build --src tests/conformance/fixtures/main_exit_logic_not_eq.fn --out artifacts/test-exit104
& $fin build --src tests/conformance/fixtures/main_exit_logic_not_or_chain.fn --out artifacts/test-exit105
& $fin build --src tests/conformance/fixtures/main_exit_logic_not_add_precedence.fn --out artifacts/test-exit106
& $fin build --src tests/conformance/fixtures/main_exit_bool_true_literal.fn --out artifacts/test-exit107
& $fin build --src tests/conformance/fixtures/main_exit_bool_false_literal.fn --out artifacts/test-exit108
& $fin build --src tests/conformance/fixtures/main_exit_bool_if_condition.fn --out artifacts/test-exit109
& $fin build --src tests/conformance/fixtures/main_exit_bool_logic_mix.fn --out artifacts/test-exit110
& $fin build --src tests/conformance/fixtures/main_exit_mod_literals.fn --out artifacts/test-exit111
& $fin build --src tests/conformance/fixtures/main_exit_mod_precedence.fn --out artifacts/test-exit112
& $fin build --src tests/conformance/fixtures/main_exit_mod_grouped.fn --out artifacts/test-exit113
& $fin build --src tests/conformance/fixtures/main_exit_bitwise_and_literals.fn --out artifacts/test-exit114
& $fin build --src tests/conformance/fixtures/main_exit_bitwise_or_literals.fn --out artifacts/test-exit115
& $fin build --src tests/conformance/fixtures/main_exit_bitwise_xor_literals.fn --out artifacts/test-exit116
& $fin build --src tests/conformance/fixtures/main_exit_bitwise_precedence.fn --out artifacts/test-exit117
& $fin build --src tests/conformance/fixtures/main_exit_bitwise_cmp_precedence.fn --out artifacts/test-exit118
& $fin build --src tests/conformance/fixtures/main_exit_shift_left_literals.fn --out artifacts/test-exit120
& $fin build --src tests/conformance/fixtures/main_exit_shift_right_literals.fn --out artifacts/test-exit121
& $fin build --src tests/conformance/fixtures/main_exit_shift_precedence.fn --out artifacts/test-exit123
& $fin build --src tests/conformance/fixtures/main_exit_shift_cmp_precedence.fn --out artifacts/test-exit123b
& $fin build --src tests/conformance/fixtures/main_exit_bitwise_not_literal.fn --out artifacts/test-exit124
& $fin build --src tests/conformance/fixtures/main_exit_bitwise_not_bitwise_mix.fn --out artifacts/test-exit126
& $fin build --src tests/conformance/fixtures/main_exit_bitwise_not_shift_precedence.fn --out artifacts/test-exit127
& $fin build --src tests/conformance/fixtures/main_exit_hex_literal.fn --out artifacts/test-exit128
& $fin build --src tests/conformance/fixtures/main_exit_hex_arithmetic.fn --out artifacts/test-exit129
& $fin build --src tests/conformance/fixtures/main_exit_hex_bitwise_mix.fn --out artifacts/test-exit130
& $fin build --src tests/conformance/fixtures/main_exit_binary_literal.fn --out artifacts/test-exit131a
& $fin build --src tests/conformance/fixtures/main_exit_binary_arithmetic.fn --out artifacts/test-exit131b
& $fin build --src tests/conformance/fixtures/main_exit_binary_bitwise_mix.fn --out artifacts/test-exit131c
& $fin build --src tests/conformance/fixtures/main_exit_try_literal.fn --out artifacts/test-exit11
& $fin build --src tests/conformance/fixtures/main_exit_try_identifier.fn --out artifacts/test-exit12
& $fin build --src tests/conformance/fixtures/main_exit_try_ok_result.fn --out artifacts/test-exit13
& $fin build --src tests/conformance/fixtures/main_exit_result_typed_binding.fn --out artifacts/test-exit14
& $fin build --src tests/conformance/fixtures/main_exit_try_move_ok_result.fn --out artifacts/test-exit30
& $fin build --src tests/conformance/fixtures/main_exit_try_ok_move_u8.fn --out artifacts/test-exit31
& $fin build --src tests/conformance/fixtures/main_exit_err_move_u8.fn --out artifacts/test-exit32
& $fin build --src tests/conformance/fixtures/main_exit_try_move_ok_move_u8.fn --out artifacts/test-exit33
& $fin build --src tests/conformance/fixtures/main_exit_try_move_result_reinit_move_again.fn --out artifacts/test-exit35
& $fin build --src tests/conformance/fixtures/main_exit_try_move_result_reinit_drop_reinit.fn --out artifacts/test-exit38
& $fin build --src tests/conformance/fixtures/main_exit_try_move_other_result_assign.fn --out artifacts/test-exit41
& $fin build --src tests/conformance/fixtures/main_exit_try_move_ok_nested_wrapper.fn --out artifacts/test-exit43
& $fin build --src tests/conformance/fixtures/main_exit_err_try_move_ok_identifier.fn --out artifacts/test-exit45
& $fin build --src tests/conformance/fixtures/main_exit_err_try_move_ok_reinit_source.fn --out artifacts/test-exit48
& $fin build --src tests/conformance/fixtures/main_exit_ok_try_move_ok_reinit_source.fn --out artifacts/test-exit51
& $fin build --src tests/conformance/fixtures/main_exit_ok_try_move_ok_reinit_drop_reinit_source.fn --out artifacts/test-exit55
& $fin build --src tests/conformance/fixtures/main_exit_err_try_move_ok_reinit_drop_reinit_source.fn --out artifacts/test-exit59
& $fin build --src tests/conformance/fixtures/main_drop_unused.fn --out artifacts/test-exit15
& $fin build --src tests/conformance/fixtures/main_move_binding.fn --out artifacts/test-exit16
& $fin build --src tests/conformance/fixtures/main_move_reinit_var.fn --out artifacts/test-exit17
& $fin build --src tests/conformance/fixtures/main_drop_reinit_var.fn --out artifacts/test-exit18
& $fin build --src tests/conformance/fixtures/main_move_reinit_move_again.fn --out artifacts/test-exit19
& $fin build --src tests/conformance/fixtures/main_drop_reinit_move.fn --out artifacts/test-exit20
& $fin build --src tests/conformance/fixtures/main_drop_reinit_drop_reinit.fn --out artifacts/test-exit22
& $fin build --src tests/conformance/fixtures/main_result_move_reinit_var.fn --out artifacts/test-exit23
& $fin build --src tests/conformance/fixtures/main_result_drop_reinit_var.fn --out artifacts/test-exit24
& $fin build --src tests/conformance/fixtures/main_result_drop_reinit_move.fn --out artifacts/test-exit25
& $fin build --src tests/conformance/fixtures/main_result_move_reinit_move_again.fn --out artifacts/test-exit26
& $fin build --src tests/conformance/fixtures/main_result_drop_reinit_drop_reinit.fn --out artifacts/test-exit27
& $fin build --src tests/conformance/fixtures/main_exit_err_unused.fn --out artifacts/test-exit28
& $fin build --src tests/conformance/fixtures/main_exit_err_binding_ok_path.fn --out artifacts/test-exit29

if (-not $SkipRun) {
    & $fin run --no-build --out artifacts/test-exit0 --expect-exit 0
    if (-not $Quick) {
        & $fin run --no-build --out artifacts/test-exit7 --expect-exit 7
        & $fin run --no-build --out artifacts/test-exit8 --expect-exit 8
        & $fin run --no-build --out artifacts/test-exit9 --expect-exit 9
        & $fin run --no-build --out artifacts/test-exit10 --expect-exit 10
        & $fin run --no-build --out artifacts/test-exit21 --expect-exit 21
        & $fin run --no-build --out artifacts/test-exit42 --expect-exit 42
        & $fin run --no-build --out artifacts/test-exit57 --expect-exit 57
        & $fin run --no-build --out artifacts/test-exit63 --expect-exit 63
        & $fin run --no-build --out artifacts/test-exit66 --expect-exit 66
        & $fin run --no-build --out artifacts/test-exit65 --expect-exit 65
        & $fin run --no-build --out artifacts/test-exit80 --expect-exit 80
        & $fin run --no-build --out artifacts/test-exit82 --expect-exit 82
        & $fin run --no-build --out artifacts/test-exit83 --expect-exit 83
        & $fin run --no-build --out artifacts/test-exit86 --expect-exit 86
        & $fin run --no-build --out artifacts/test-exit90 --expect-exit 90
        & $fin run --no-build --out artifacts/test-exit91 --expect-exit 91
        & $fin run --no-build --out artifacts/test-exit92 --expect-exit 92
        & $fin run --no-build --out artifacts/test-exit93 --expect-exit 93
        & $fin run --no-build --out artifacts/test-exit94 --expect-exit 94
        & $fin run --no-build --out artifacts/test-exit95 --expect-exit 95
        & $fin run --no-build --out artifacts/test-exit96 --expect-exit 96
        & $fin run --no-build --out artifacts/test-exit97 --expect-exit 97
        & $fin run --no-build --out artifacts/test-exit98 --expect-exit 98
        & $fin run --no-build --out artifacts/test-exit99 --expect-exit 99
        & $fin run --no-build --out artifacts/test-exit100 --expect-exit 100
        & $fin run --no-build --out artifacts/test-exit101 --expect-exit 101
        & $fin run --no-build --out artifacts/test-exit102 --expect-exit 102
        & $fin run --no-build --out artifacts/test-exit103 --expect-exit 103
        & $fin run --no-build --out artifacts/test-exit104 --expect-exit 104
        & $fin run --no-build --out artifacts/test-exit105 --expect-exit 105
        & $fin run --no-build --out artifacts/test-exit106 --expect-exit 106
        & $fin run --no-build --out artifacts/test-exit107 --expect-exit 107
        & $fin run --no-build --out artifacts/test-exit108 --expect-exit 108
        & $fin run --no-build --out artifacts/test-exit109 --expect-exit 109
        & $fin run --no-build --out artifacts/test-exit110 --expect-exit 110
        & $fin run --no-build --out artifacts/test-exit111 --expect-exit 111
        & $fin run --no-build --out artifacts/test-exit112 --expect-exit 112
        & $fin run --no-build --out artifacts/test-exit113 --expect-exit 113
        & $fin run --no-build --out artifacts/test-exit114 --expect-exit 114
        & $fin run --no-build --out artifacts/test-exit115 --expect-exit 115
        & $fin run --no-build --out artifacts/test-exit116 --expect-exit 116
        & $fin run --no-build --out artifacts/test-exit117 --expect-exit 117
        & $fin run --no-build --out artifacts/test-exit118 --expect-exit 118
        & $fin run --no-build --out artifacts/test-exit120 --expect-exit 120
        & $fin run --no-build --out artifacts/test-exit121 --expect-exit 121
        & $fin run --no-build --out artifacts/test-exit123 --expect-exit 123
        & $fin run --no-build --out artifacts/test-exit123b --expect-exit 123
        & $fin run --no-build --out artifacts/test-exit124 --expect-exit 124
        & $fin run --no-build --out artifacts/test-exit126 --expect-exit 126
        & $fin run --no-build --out artifacts/test-exit127 --expect-exit 127
        & $fin run --no-build --out artifacts/test-exit128 --expect-exit 128
        & $fin run --no-build --out artifacts/test-exit129 --expect-exit 129
        & $fin run --no-build --out artifacts/test-exit130 --expect-exit 130
        & $fin run --no-build --out artifacts/test-exit131a --expect-exit 131
        & $fin run --no-build --out artifacts/test-exit131b --expect-exit 131
        & $fin run --no-build --out artifacts/test-exit131c --expect-exit 131
        & $fin run --no-build --out artifacts/test-exit11 --expect-exit 11
        & $fin run --no-build --out artifacts/test-exit12 --expect-exit 12
        & $fin run --no-build --out artifacts/test-exit13 --expect-exit 13
        & $fin run --no-build --out artifacts/test-exit14 --expect-exit 14
        & $fin run --no-build --out artifacts/test-exit30 --expect-exit 30
        & $fin run --no-build --out artifacts/test-exit31 --expect-exit 31
        & $fin run --no-build --out artifacts/test-exit32 --expect-exit 32
        & $fin run --no-build --out artifacts/test-exit33 --expect-exit 33
        & $fin run --no-build --out artifacts/test-exit35 --expect-exit 35
        & $fin run --no-build --out artifacts/test-exit38 --expect-exit 38
        & $fin run --no-build --out artifacts/test-exit41 --expect-exit 41
        & $fin run --no-build --out artifacts/test-exit43 --expect-exit 43
        & $fin run --no-build --out artifacts/test-exit45 --expect-exit 45
        & $fin run --no-build --out artifacts/test-exit48 --expect-exit 48
        & $fin run --no-build --out artifacts/test-exit51 --expect-exit 51
        & $fin run --no-build --out artifacts/test-exit55 --expect-exit 55
        & $fin run --no-build --out artifacts/test-exit59 --expect-exit 59
        & $fin run --no-build --out artifacts/test-exit15 --expect-exit 15
        & $fin run --no-build --out artifacts/test-exit16 --expect-exit 16
        & $fin run --no-build --out artifacts/test-exit17 --expect-exit 17
        & $fin run --no-build --out artifacts/test-exit18 --expect-exit 18
        & $fin run --no-build --out artifacts/test-exit19 --expect-exit 19
        & $fin run --no-build --out artifacts/test-exit20 --expect-exit 20
        & $fin run --no-build --out artifacts/test-exit22 --expect-exit 22
        & $fin run --no-build --out artifacts/test-exit23 --expect-exit 23
        & $fin run --no-build --out artifacts/test-exit24 --expect-exit 24
        & $fin run --no-build --out artifacts/test-exit25 --expect-exit 25
        & $fin run --no-build --out artifacts/test-exit26 --expect-exit 26
        & $fin run --no-build --out artifacts/test-exit27 --expect-exit 27
        & $fin run --no-build --out artifacts/test-exit28 --expect-exit 28
        & $fin run --no-build --out artifacts/test-exit29 --expect-exit 29
    }
}

Write-Host "fin test: stage0 suite passed"

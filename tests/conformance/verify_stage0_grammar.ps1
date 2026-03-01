Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$parser = Join-Path $repoRoot "compiler/finc/stage0/parse_main_exit.ps1"

function Assert-ParseExit {
    param(
        [string]$RelativePath,
        [int]$ExpectedExit
    )

    $path = Join-Path $repoRoot $RelativePath
    $actual = [int](& $parser -SourcePath $path)
    if ($actual -ne $ExpectedExit) {
        Write-Error ("Expected {0} to parse with exit code {1}, got {2}." -f $RelativePath, $ExpectedExit, $actual)
        exit 1
    }
}

function Assert-ParseFail {
    param([string]$RelativePath)

    $path = Join-Path $repoRoot $RelativePath
    $failed = $false
    try {
        & $parser -SourcePath $path | Out-Null
    }
    catch {
        $failed = $true
    }

    if (-not $failed) {
        Write-Error ("Expected invalid fixture to fail parsing: {0}" -f $RelativePath)
        exit 1
    }
}

function Assert-ParseFailContains {
    param(
        [string]$RelativePath,
        [string]$ExpectedMessagePart
    )

    $path = Join-Path $repoRoot $RelativePath
    $failed = $false
    $message = ""
    try {
        & $parser -SourcePath $path | Out-Null
    }
    catch {
        $failed = $true
        $message = $_.ToString()
    }

    if (-not $failed) {
        Write-Error ("Expected invalid fixture to fail parsing: {0}" -f $RelativePath)
        exit 1
    }

    if ($message -notlike ("*" + $ExpectedMessagePart + "*")) {
        Write-Error (
            "Expected parse failure for {0} to contain '{1}', got: {2}" -f $RelativePath, $ExpectedMessagePart, $message
        )
        exit 1
    }
}

Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit0.fn" -ExpectedExit 0
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit7.fn" -ExpectedExit 7
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_let7.fn" -ExpectedExit 7
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_var_assign.fn" -ExpectedExit 8
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_comments.fn" -ExpectedExit 9
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_typed_u8.fn" -ExpectedExit 9
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_signature_u8.fn" -ExpectedExit 10
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_literal.fn" -ExpectedExit 11
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_identifier.fn" -ExpectedExit 12
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_ok_result.fn" -ExpectedExit 13
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_result_typed_binding.fn" -ExpectedExit 14
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_drop_unused.fn" -ExpectedExit 15
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_move_binding.fn" -ExpectedExit 16
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_move_reinit_var.fn" -ExpectedExit 17
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_drop_reinit_var.fn" -ExpectedExit 18
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_move_reinit_move_again.fn" -ExpectedExit 19
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_drop_reinit_move.fn" -ExpectedExit 20
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_drop_reinit_drop_reinit.fn" -ExpectedExit 22
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_result_move_reinit_var.fn" -ExpectedExit 23
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_result_drop_reinit_var.fn" -ExpectedExit 24
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_result_drop_reinit_move.fn" -ExpectedExit 25
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_result_move_reinit_move_again.fn" -ExpectedExit 26
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_result_drop_reinit_drop_reinit.fn" -ExpectedExit 27

Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_missing_main.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_undefined_identifier.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_assign_immutable.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_unsupported_type_annotation.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_unsupported_return_annotation.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_try_missing_expression.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_try_err_result.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_try_non_result_literal.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_result_annotation_mismatch.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_unsupported_result_annotation.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_borrow_reference_expr.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_dereference_expr.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_borrow_type_annotation.fn"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_use_after_drop.fn" -ExpectedMessagePart "use after drop for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_use_after_redrop.fn" -ExpectedMessagePart "use after drop for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_double_drop.fn" -ExpectedMessagePart "double drop for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_assign_after_drop.fn" -ExpectedMessagePart "cannot reinitialize dropped immutable binding 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_assign_after_move_immutable.fn" -ExpectedMessagePart "cannot reinitialize moved immutable binding 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_drop_undefined.fn" -ExpectedMessagePart "drop for undefined identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_use_after_move.fn" -ExpectedMessagePart "use after move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_double_move.fn" -ExpectedMessagePart "double move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_move_undefined.fn" -ExpectedMessagePart "move for undefined identifier 'other'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_drop_after_move.fn" -ExpectedMessagePart "drop after move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_move_after_drop.fn" -ExpectedMessagePart "move after drop for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_self_move_assignment.fn" -ExpectedMessagePart "assignment target 'value' moved or dropped during expression evaluation"

Write-Host "Stage0 grammar conformance check passed."

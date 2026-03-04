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
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_add_literals.fn" -ExpectedExit 21
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_add_identifier_literal.fn" -ExpectedExit 42
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_sub_literals.fn" -ExpectedExit 57
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_mul_literals.fn" -ExpectedExit 63
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_div_literals.fn" -ExpectedExit 66
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_mul_precedence.fn" -ExpectedExit 65
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_mul_grouped.fn" -ExpectedExit 80
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_cmp_eq_true.fn" -ExpectedExit 82
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_cmp_lt_true.fn" -ExpectedExit 83
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_cmp_precedence.fn" -ExpectedExit 86
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_cmp_ge_false_bias.fn" -ExpectedExit 90
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_if_true_literal.fn" -ExpectedExit 91
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_if_false_literal.fn" -ExpectedExit 92
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_if_cmp_condition.fn" -ExpectedExit 93
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_if_move_then_selected.fn" -ExpectedExit 94
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_if_move_else_selected.fn" -ExpectedExit 95
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_if_result_branches_try.fn" -ExpectedExit 96
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_logic_and_true.fn" -ExpectedExit 97
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_logic_or_true.fn" -ExpectedExit 98
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_logic_precedence.fn" -ExpectedExit 99
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_logic_and_short_circuit_move_rhs.fn" -ExpectedExit 100
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_logic_or_short_circuit_move_rhs.fn" -ExpectedExit 101
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_logic_not_true.fn" -ExpectedExit 102
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_logic_not_false.fn" -ExpectedExit 103
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_logic_not_eq.fn" -ExpectedExit 104
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_logic_not_or_chain.fn" -ExpectedExit 105
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_logic_not_add_precedence.fn" -ExpectedExit 106
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_bool_true_literal.fn" -ExpectedExit 107
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_bool_false_literal.fn" -ExpectedExit 108
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_bool_if_condition.fn" -ExpectedExit 109
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_bool_logic_mix.fn" -ExpectedExit 110
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_mod_literals.fn" -ExpectedExit 111
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_mod_precedence.fn" -ExpectedExit 112
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_mod_grouped.fn" -ExpectedExit 113
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_bitwise_and_literals.fn" -ExpectedExit 114
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_bitwise_or_literals.fn" -ExpectedExit 115
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_bitwise_xor_literals.fn" -ExpectedExit 116
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_bitwise_precedence.fn" -ExpectedExit 117
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_bitwise_cmp_precedence.fn" -ExpectedExit 118
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_shift_left_literals.fn" -ExpectedExit 120
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_shift_right_literals.fn" -ExpectedExit 121
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_shift_precedence.fn" -ExpectedExit 123
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_shift_cmp_precedence.fn" -ExpectedExit 123
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_bitwise_not_literal.fn" -ExpectedExit 124
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_bitwise_not_bitwise_mix.fn" -ExpectedExit 126
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_bitwise_not_shift_precedence.fn" -ExpectedExit 127
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_hex_literal.fn" -ExpectedExit 128
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_hex_arithmetic.fn" -ExpectedExit 129
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_hex_bitwise_mix.fn" -ExpectedExit 130
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_binary_literal.fn" -ExpectedExit 131
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_binary_arithmetic.fn" -ExpectedExit 131
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_binary_bitwise_mix.fn" -ExpectedExit 131
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_return_literal.fn" -ExpectedExit 132
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_return_expression.fn" -ExpectedExit 133
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_return_parenthesized.fn" -ExpectedExit 134
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_literal.fn" -ExpectedExit 11
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_identifier.fn" -ExpectedExit 12
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_ok_result.fn" -ExpectedExit 13
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_result_typed_binding.fn" -ExpectedExit 14
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_move_ok_result.fn" -ExpectedExit 30
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_ok_move_u8.fn" -ExpectedExit 31
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_err_move_u8.fn" -ExpectedExit 32
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_move_ok_move_u8.fn" -ExpectedExit 33
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_move_result_reinit_move_again.fn" -ExpectedExit 35
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_move_result_reinit_drop_reinit.fn" -ExpectedExit 38
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_move_other_result_assign.fn" -ExpectedExit 41
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_move_ok_nested_wrapper.fn" -ExpectedExit 43
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_err_try_move_ok_identifier.fn" -ExpectedExit 45
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_err_try_move_ok_reinit_source.fn" -ExpectedExit 48
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_ok_try_move_ok_reinit_source.fn" -ExpectedExit 51
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_ok_try_move_ok_reinit_drop_reinit_source.fn" -ExpectedExit 55
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_err_try_move_ok_reinit_drop_reinit_source.fn" -ExpectedExit 59
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_postfix_ok_result.fn" -ExpectedExit 135
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_postfix_move_ok_result.fn" -ExpectedExit 136
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_postfix_arithmetic.fn" -ExpectedExit 137
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_space_ok_result.fn" -ExpectedExit 138
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_space_move_ok_result.fn" -ExpectedExit 139
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_space_arithmetic.fn" -ExpectedExit 140
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_let_unwrap_binding_ok.fn" -ExpectedExit 141
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_let_unwrap_binding_move_ok.fn" -ExpectedExit 142
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_let_unwrap_binding_arithmetic.fn" -ExpectedExit 143
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_unwrap_assignment_ok.fn" -ExpectedExit 144
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_unwrap_assignment_move_ok.fn" -ExpectedExit 145
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_unwrap_assignment_arithmetic.fn" -ExpectedExit 146
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_var_unwrap_binding_ok.fn" -ExpectedExit 147
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_var_unwrap_binding_move_ok.fn" -ExpectedExit 148
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_var_unwrap_binding_arithmetic.fn" -ExpectedExit 149
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
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_err_unused.fn" -ExpectedExit 28
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_err_binding_ok_path.fn" -ExpectedExit 29

Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_missing_main.fn" -ExpectedMessagePart "expected entrypoint pattern fn main()"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_undefined_identifier.fn" -ExpectedMessagePart "undefined identifier 'code'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_assign_immutable.fn" -ExpectedMessagePart "cannot assign to immutable binding 'code'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_add_non_u8_operand.fn" -ExpectedMessagePart "operator '+' expects u8 operands in stage0, found Result<u8,u8> and u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_add_overflow.fn" -ExpectedMessagePart "u8 overflow in '+' expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_sub_underflow.fn" -ExpectedMessagePart "u8 underflow in '-' expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_mul_non_u8_operand.fn" -ExpectedMessagePart "operator '*' expects u8 operands in stage0, found Result<u8,u8> and u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_mul_overflow.fn" -ExpectedMessagePart "u8 overflow in '*' expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_div_by_zero.fn" -ExpectedMessagePart "division by zero in '/' expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_mod_non_u8_operand.fn" -ExpectedMessagePart "operator '%' expects u8 operands in stage0, found Result<u8,u8> and u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_mod_by_zero.fn" -ExpectedMessagePart "modulo by zero in '%' expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_mod_missing_rhs.fn" -ExpectedMessagePart "binary operator '%' requires both operands"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_bitwise_non_u8_operand.fn" -ExpectedMessagePart "operator '|' expects u8 operands in stage0, found Result<u8,u8> and u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_bitwise_missing_rhs.fn" -ExpectedMessagePart "binary operator '^' requires both operands"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_shift_non_u8_operand.fn" -ExpectedMessagePart "operator '<<' expects u8 operands in stage0, found Result<u8,u8> and u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_shift_missing_rhs.fn" -ExpectedMessagePart "binary operator '<<' requires both operands"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_shift_left_count_out_of_range.fn" -ExpectedMessagePart "shift count out of range 0..7 in '<<' expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_shift_right_count_out_of_range.fn" -ExpectedMessagePart "shift count out of range 0..7 in '>>' expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_shift_left_overflow.fn" -ExpectedMessagePart "u8 overflow in '<<' expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_bitwise_not_non_u8_operand.fn" -ExpectedMessagePart "operator '~' expects u8 operand in stage0, found Result<u8,u8>"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_bitwise_not_missing_operand.fn" -ExpectedMessagePart "bitwise not '~' requires an operand"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_hex_literal_non_hex_digit.fn" -ExpectedMessagePart "invalid hex literal '0xG1'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_hex_literal_prefix_only.fn" -ExpectedMessagePart "invalid hex literal '0x'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_hex_literal_out_of_range.fn" -ExpectedMessagePart "exit/value literal must be in range 0..255"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_binary_literal_non_binary_digit.fn" -ExpectedMessagePart "invalid binary literal '0b102'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_binary_literal_prefix_only.fn" -ExpectedMessagePart "invalid binary literal '0b'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_binary_literal_out_of_range.fn" -ExpectedMessagePart "exit/value literal must be in range 0..255"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_return_missing_expression.fn" -ExpectedMessagePart "return statement requires expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_return_empty_parenthesized.fn" -ExpectedMessagePart "return statement requires expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_return_non_u8_expression.fn" -ExpectedMessagePart "return expression type must be u8, found Result<u8,u8>"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_statement_after_return.fn" -ExpectedMessagePart "statements after terminal exit/return are not allowed in stage0"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_empty_parenthesized_expr.fn" -ExpectedMessagePart "parenthesized expression must not be empty"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_cmp_non_u8_operand.fn" -ExpectedMessagePart "operator '==' expects u8 operands in stage0, found Result<u8,u8> and u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_cmp_missing_rhs.fn" -ExpectedMessagePart "binary operator '<' requires both operands"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_if_missing_argument.fn" -ExpectedMessagePart "if(...) requires exactly 3 arguments: condition, then, else"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_if_empty_argument.fn" -ExpectedMessagePart "if(...) arguments must not be empty"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_if_non_u8_condition.fn" -ExpectedMessagePart "if(...) condition expects u8 in stage0, found Result<u8,u8>"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_if_branch_type_mismatch.fn" -ExpectedMessagePart "if(...) branch type mismatch: then is u8, else is Result<u8,u8>"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_logic_non_u8_operand_and.fn" -ExpectedMessagePart "operator '&&' expects u8 operands in stage0, found u8 and Result<u8,u8>"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_logic_non_u8_operand_or_short_circuit.fn" -ExpectedMessagePart "operator '||' expects u8 operands in stage0, found u8 and Result<u8,u8>"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_logic_missing_rhs.fn" -ExpectedMessagePart "binary operator '&&' requires both operands"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_logic_and_use_after_move_rhs_selected.fn" -ExpectedMessagePart "use after move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_logic_or_use_after_move_rhs_selected.fn" -ExpectedMessagePart "use after move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_logic_not_non_u8_operand.fn" -ExpectedMessagePart "operator '!' expects u8 operand in stage0, found Result<u8,u8>"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_logic_not_missing_operand.fn" -ExpectedMessagePart "logical not '!' requires an operand"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_logic_not_use_after_move.fn" -ExpectedMessagePart "use after move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_bool_keyword_binding_true.fn" -ExpectedMessagePart "reserved keyword cannot be used as identifier 'true'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_bool_keyword_assignment_true.fn" -ExpectedMessagePart "reserved keyword cannot be used as identifier 'true'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_unsupported_type_annotation.fn" -ExpectedMessagePart "unsupported type annotation 'i32'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_unsupported_return_annotation.fn" -ExpectedMessagePart "unsupported type annotation 'i32'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_return_annotation.fn" -ExpectedMessagePart "entrypoint return type must be u8 in stage0 bootstrap, found Result<u8,u8>"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_try_missing_expression.fn"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_missing_expression.fn" -ExpectedMessagePart "try(...) requires an inner expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_ok_missing_expression.fn" -ExpectedMessagePart "ok(...) requires an inner expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_err_missing_expression.fn" -ExpectedMessagePart "err(...) requires an inner expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_ok_non_u8_identifier.fn" -ExpectedMessagePart "ok(...) expects u8 expression in stage0, found Result<u8,u8>"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_err_non_u8_identifier.fn" -ExpectedMessagePart "err(...) expects u8 expression in stage0, found Result<u8,u8>"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_ok_move_non_u8_identifier.fn" -ExpectedMessagePart "ok(...) expects u8 expression in stage0, found Result<u8,u8>"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_err_move_non_u8_identifier.fn" -ExpectedMessagePart "err(...) expects u8 expression in stage0, found Result<u8,u8>"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_try_err_result.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_try_non_result_literal.fn"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_err_result.fn" -ExpectedMessagePart "try(err(...)) is not supported in stage0 bootstrap (would require hidden control flow)"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_err_identifier.fn" -ExpectedMessagePart "try(err(...)) is not supported in stage0 bootstrap (would require hidden control flow)"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_move_err_identifier.fn" -ExpectedMessagePart "try(err(...)) is not supported in stage0 bootstrap (would require hidden control flow)"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_ok_try_err_identifier.fn" -ExpectedMessagePart "try(err(...)) is not supported in stage0 bootstrap (would require hidden control flow)"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_err_try_err_identifier.fn" -ExpectedMessagePart "try(err(...)) is not supported in stage0 bootstrap (would require hidden control flow)"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_ok_try_move_err_identifier.fn" -ExpectedMessagePart "try(err(...)) is not supported in stage0 bootstrap (would require hidden control flow)"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_err_try_move_err_identifier.fn" -ExpectedMessagePart "try(err(...)) is not supported in stage0 bootstrap (would require hidden control flow)"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_err_try_move_use_after_move_source.fn" -ExpectedMessagePart "use after move for identifier 'source'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_ok_try_move_use_after_move_source.fn" -ExpectedMessagePart "use after move for identifier 'source'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_ok_try_move_drop_after_move_source.fn" -ExpectedMessagePart "drop after move for identifier 'source'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_err_try_move_drop_after_move_source.fn" -ExpectedMessagePart "drop after move for identifier 'source'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_ok_try_move_assign_after_move_immutable_source.fn" -ExpectedMessagePart "cannot reinitialize moved immutable binding 'source'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_err_try_move_assign_after_move_immutable_source.fn" -ExpectedMessagePart "cannot reinitialize moved immutable binding 'source'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_non_result_literal.fn" -ExpectedMessagePart "try(...) expects Result<u8,u8> in stage0 bootstrap, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_non_result_identifier.fn" -ExpectedMessagePart "try(...) expects Result<u8,u8> in stage0 bootstrap, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_move_non_result_identifier.fn" -ExpectedMessagePart "try(...) expects Result<u8,u8> in stage0 bootstrap, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_ok_try_non_result_identifier.fn" -ExpectedMessagePart "try(...) expects Result<u8,u8> in stage0 bootstrap, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_err_try_non_result_identifier.fn" -ExpectedMessagePart "try(...) expects Result<u8,u8> in stage0 bootstrap, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_ok_try_move_non_result_identifier.fn" -ExpectedMessagePart "try(...) expects Result<u8,u8> in stage0 bootstrap, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_err_try_move_non_result_identifier.fn" -ExpectedMessagePart "try(...) expects Result<u8,u8> in stage0 bootstrap, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_move_result_use_after_move.fn" -ExpectedMessagePart "use after move for identifier 'wrapped'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_move_result_assign_after_move_immutable.fn" -ExpectedMessagePart "cannot reinitialize moved immutable binding 'wrapped'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_move_result_drop_after_move.fn" -ExpectedMessagePart "drop after move for identifier 'wrapped'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_move_result_self_assignment.fn" -ExpectedMessagePart "assignment target 'wrapped' moved or dropped during expression evaluation"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_postfix_missing_operand.fn" -ExpectedMessagePart "postfix '?' requires an operand"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_postfix_non_result_identifier.fn" -ExpectedMessagePart "postfix '?' expects Result<u8,u8> in stage0 bootstrap, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_postfix_err_identifier.fn" -ExpectedMessagePart "postfix '?' on err(...) is not supported in stage0 bootstrap (would require hidden control flow)"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_postfix_move_use_after_move_source.fn" -ExpectedMessagePart "use after move for identifier 'source'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_space_missing_expression.fn" -ExpectedMessagePart "try keyword requires expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_space_non_result_identifier.fn" -ExpectedMessagePart "try keyword expects Result<u8,u8> in stage0 bootstrap, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_space_err_identifier.fn" -ExpectedMessagePart "try keyword on err(...) is not supported in stage0 bootstrap (would require hidden control flow)"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_try_space_move_use_after_move_source.fn" -ExpectedMessagePart "use after move for identifier 'source'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_let_unwrap_binding_missing_expression.fn" -ExpectedMessagePart "unwrap binding requires expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_let_unwrap_binding_non_result_identifier.fn" -ExpectedMessagePart "try keyword expects Result<u8,u8> in stage0 bootstrap, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_let_unwrap_binding_err_identifier.fn" -ExpectedMessagePart "try keyword on err(...) is not supported in stage0 bootstrap (would require hidden control flow)"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_let_unwrap_binding_move_use_after_move_source.fn" -ExpectedMessagePart "use after move for identifier 'source'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_unwrap_assignment_missing_expression.fn" -ExpectedMessagePart "unwrap assignment requires expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_unwrap_assignment_non_result_identifier.fn" -ExpectedMessagePart "try keyword expects Result<u8,u8> in stage0 bootstrap, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_unwrap_assignment_err_identifier.fn" -ExpectedMessagePart "try keyword on err(...) is not supported in stage0 bootstrap (would require hidden control flow)"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_unwrap_assignment_immutable_target.fn" -ExpectedMessagePart "cannot assign to immutable binding 'code'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_unwrap_assignment_move_use_after_move_source.fn" -ExpectedMessagePart "use after move for identifier 'source'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_var_unwrap_binding_missing_expression.fn" -ExpectedMessagePart "unwrap var binding requires expression"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_var_unwrap_binding_non_result_identifier.fn" -ExpectedMessagePart "try keyword expects Result<u8,u8> in stage0 bootstrap, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_var_unwrap_binding_err_identifier.fn" -ExpectedMessagePart "try keyword on err(...) is not supported in stage0 bootstrap (would require hidden control flow)"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_var_unwrap_binding_move_use_after_move_source.fn" -ExpectedMessagePart "use after move for identifier 'source'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_var_unwrap_binding_duplicate.fn" -ExpectedMessagePart "duplicate binding 'code'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_annotation_mismatch.fn" -ExpectedMessagePart "type mismatch for binding 'value': expected Result<u8,u8>, found u8"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_unsupported_result_annotation.fn" -ExpectedMessagePart "unsupported type annotation 'Result<u8,i32>'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_borrow_reference_expr.fn" -ExpectedMessagePart "borrow/reference expressions are not available in stage0 bootstrap"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_dereference_expr.fn" -ExpectedMessagePart "dereference expressions are not available in stage0 bootstrap"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_borrow_type_annotation.fn" -ExpectedMessagePart "ownership/borrowing type annotations are not available in stage0 bootstrap"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_use_after_drop.fn" -ExpectedMessagePart "use after drop for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_use_after_redrop.fn" -ExpectedMessagePart "use after drop for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_double_drop.fn" -ExpectedMessagePart "double drop for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_assign_after_drop.fn" -ExpectedMessagePart "cannot reinitialize dropped immutable binding 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_assign_after_move_immutable.fn" -ExpectedMessagePart "cannot reinitialize moved immutable binding 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_drop_undefined.fn" -ExpectedMessagePart "drop for undefined identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_use_after_move.fn" -ExpectedMessagePart "use after move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_use_after_move_inside_ok.fn" -ExpectedMessagePart "use after move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_use_after_move_inside_err.fn" -ExpectedMessagePart "use after move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_double_move.fn" -ExpectedMessagePart "double move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_move_undefined.fn" -ExpectedMessagePart "move for undefined identifier 'other'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_drop_after_move.fn" -ExpectedMessagePart "drop after move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_move_after_drop.fn" -ExpectedMessagePart "move after drop for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_self_move_assignment.fn" -ExpectedMessagePart "assignment target 'value' moved or dropped during expression evaluation"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_use_after_drop.fn" -ExpectedMessagePart "use after drop for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_use_after_move.fn" -ExpectedMessagePart "use after move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_assign_after_drop_immutable.fn" -ExpectedMessagePart "cannot reinitialize dropped immutable binding 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_assign_after_move_immutable.fn" -ExpectedMessagePart "cannot reinitialize moved immutable binding 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_drop_after_move.fn" -ExpectedMessagePart "drop after move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_move_after_drop.fn" -ExpectedMessagePart "move after drop for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_double_drop.fn" -ExpectedMessagePart "double drop for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_double_move.fn" -ExpectedMessagePart "double move for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_use_after_redrop.fn" -ExpectedMessagePart "use after drop for identifier 'value'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_self_move_assignment.fn" -ExpectedMessagePart "assignment target 'value' moved or dropped during expression evaluation"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_drop_undefined.fn" -ExpectedMessagePart "drop for undefined identifier 'other'"
Assert-ParseFailContains -RelativePath "tests/conformance/fixtures/invalid_result_move_undefined.fn" -ExpectedMessagePart "move for undefined identifier 'other'"

Write-Host "Stage0 grammar conformance check passed."

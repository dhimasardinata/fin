Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$fip = Join-Path $repoRoot "fips/FIP-0008-error-model-result-try.md"
$index = Join-Path $repoRoot "fips/INDEX.md"
$parser = Join-Path $repoRoot "compiler/finc/stage0/parse_main_exit.ps1"
$grammar = Join-Path $repoRoot "tests/conformance/verify_stage0_grammar.ps1"
$suite = Join-Path $repoRoot "tests/run_stage0_suite.ps1"
$testsReadme = Join-Path $repoRoot "tests/README.md"

function Fail-ResultTryContract {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

$fipText = Get-Content -LiteralPath $fip -Raw
$indexText = Get-Content -LiteralPath $index -Raw
$parserText = Get-Content -LiteralPath $parser -Raw
$grammarText = Get-Content -LiteralPath $grammar -Raw
$suiteText = Get-Content -LiteralPath $suite -Raw
$testsReadmeText = Get-Content -LiteralPath $testsReadme -Raw

if ($fipText -notmatch "(?m)^- status: Implemented$") {
    Fail-ResultTryContract "FIP-0008 must be Implemented once the Result/try contract gate exists"
}

if ($indexText -notmatch [regex]::Escape("| FIP-0008 | Error Model (Result + try) | Implemented |")) {
    Fail-ResultTryContract "FIP index must mark FIP-0008 Implemented"
}

foreach ($path in @(
    "compiler/finc/stage0/parse_main_exit.ps1",
    "tests/conformance/verify_stage0_grammar.ps1",
    "tests/reproducibility/verify_result_try_contract.ps1",
    "tests/run_stage0_suite.ps1"
)) {
    if ($fipText -notmatch [regex]::Escape($path)) {
        Fail-ResultTryContract ("FIP-0008 implementation list missing: {0}" -f $path)
    }
}

foreach ($phrase in @(
    "ok(...) requires an inner expression",
    "err(...) requires an inner expression",
    "try(...) requires an inner expression",
    "try(err(...)) is not supported in stage0 bootstrap",
    "try keyword on err(...) is not supported in stage0 bootstrap",
    "postfix '?' on err(...) is not supported in stage0 bootstrap",
    "unwrap binding requires expression",
    "unwrap var binding requires expression",
    "unwrap assignment requires expression",
    "Result<u8,u8>",
    "try <expr>",
    "<expr>?"
)) {
    if ($parserText -notmatch [regex]::Escape($phrase)) {
        Fail-ResultTryContract ("parser missing Result/try contract phrase: {0}" -f $phrase)
    }
}

foreach ($fixture in @(
    "main_exit_try_literal.fn",
    "main_exit_try_identifier.fn",
    "main_exit_try_ok_result.fn",
    "main_exit_result_typed_binding.fn",
    "main_exit_try_move_ok_result.fn",
    "main_exit_try_postfix_ok_result.fn",
    "main_exit_try_space_ok_result.fn",
    "main_exit_let_unwrap_binding_ok.fn",
    "main_exit_unwrap_assignment_ok.fn",
    "main_exit_var_unwrap_binding_ok.fn",
    "main_exit_helper_result_try.fn",
    "main_exit_helper_params_result_try.fn",
    "invalid_try_err_result.fn",
    "invalid_try_non_result_identifier.fn",
    "invalid_try_postfix_err_identifier.fn",
    "invalid_try_space_err_identifier.fn",
    "invalid_let_unwrap_binding_err_identifier.fn",
    "invalid_unwrap_assignment_immutable_target.fn",
    "invalid_var_unwrap_binding_duplicate.fn",
    "invalid_helper_call_type_mismatch.fn"
)) {
    if ($grammarText -notmatch [regex]::Escape($fixture)) {
        Fail-ResultTryContract ("grammar verifier missing Result/try fixture: {0}" -f $fixture)
    }
}

foreach ($phrase in @(
    "try(...) requires an inner expression",
    "try(...) expects Result<u8,u8> in stage0 bootstrap",
    "try(err(...)) is not supported in stage0 bootstrap",
    "postfix '?' expects Result<u8,u8> in stage0 bootstrap",
    "try keyword expects Result<u8,u8> in stage0 bootstrap",
    "cannot assign to immutable binding",
    "duplicate binding",
    "type mismatch for parameter"
)) {
    if ($grammarText -notmatch [regex]::Escape($phrase)) {
        Fail-ResultTryContract ("grammar verifier missing Result/try diagnostic phrase: {0}" -f $phrase)
    }
}

foreach ($fixture in @(
    "main_exit_try_literal.fn",
    "main_exit_try_ok_result.fn",
    "main_exit_result_typed_binding.fn",
    "main_exit_try_move_ok_result.fn",
    "main_exit_try_postfix_ok_result.fn",
    "main_exit_try_space_ok_result.fn",
    "main_exit_let_unwrap_binding_ok.fn",
    "main_exit_unwrap_assignment_ok.fn",
    "main_exit_var_unwrap_binding_ok.fn",
    "main_exit_helper_result_try.fn",
    "main_exit_helper_params_result_try.fn"
)) {
    if ($suiteText -notmatch [regex]::Escape($fixture)) {
        Fail-ResultTryContract ("stage0 suite missing runtime Result/try fixture: {0}" -f $fixture)
    }
}

if ($suiteText -notmatch [regex]::Escape('tests/reproducibility/verify_result_try_contract.ps1')) {
    Fail-ResultTryContract "stage0 suite must call the Result/try contract verifier"
}

if ($testsReadmeText -notmatch [regex]::Escape("verify_result_try_contract.ps1")) {
    Fail-ResultTryContract "tests README must document the Result/try contract verifier"
}

Write-Host "Result/try contract check passed."

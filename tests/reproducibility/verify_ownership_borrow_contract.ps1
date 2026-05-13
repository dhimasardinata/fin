Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$fip = Join-Path $repoRoot "fips/FIP-0007-ownership-borrowing-inference-first.md"
$index = Join-Path $repoRoot "fips/INDEX.md"
$parser = Join-Path $repoRoot "compiler/finc/stage0/parse_main_exit.ps1"
$grammar = Join-Path $repoRoot "tests/conformance/verify_stage0_grammar.ps1"
$suite = Join-Path $repoRoot "tests/run_stage0_suite.ps1"
$testsReadme = Join-Path $repoRoot "tests/README.md"

function Fail-OwnershipBorrowContract {
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
    Fail-OwnershipBorrowContract "FIP-0007 must be Implemented once the ownership/borrow contract gate exists"
}

if ($indexText -notmatch [regex]::Escape("| FIP-0007 | Ownership and Borrowing (Inference-First) | Implemented |")) {
    Fail-OwnershipBorrowContract "FIP index must mark FIP-0007 Implemented"
}

foreach ($path in @(
    "compiler/finc/stage0/parse_main_exit.ps1",
    "tests/conformance/verify_stage0_grammar.ps1",
    "tests/reproducibility/verify_ownership_borrow_contract.ps1",
    "tests/run_stage0_suite.ps1"
)) {
    if ($fipText -notmatch [regex]::Escape($path)) {
        Fail-OwnershipBorrowContract ("FIP-0007 implementation list missing: {0}" -f $path)
    }
}

foreach ($phrase in @(
    "LifecycleStates",
    "ReferenceTargets",
    "use after move for identifier",
    "use after drop for identifier",
    "double drop for identifier",
    "double move for identifier",
    "drop after move for identifier",
    "move after drop for identifier",
    "cannot reinitialize moved immutable binding",
    "cannot move identifier",
    "cannot assign identifier",
    "cannot leave block while identifier",
    "borrow '&' expects identifier operand in stage0",
    "dereference '*' requires an operand",
    "dereference expects reference operand in stage0",
    "Remove-BlockScopedBindings",
    "&u8",
    "&Result<u8,u8>"
)) {
    if ($parserText -notmatch [regex]::Escape($phrase)) {
        Fail-OwnershipBorrowContract ("parser missing ownership/borrow contract phrase: {0}" -f $phrase)
    }
}

foreach ($fixture in @(
    "main_drop_unused.fn",
    "main_move_binding.fn",
    "main_move_reinit_var.fn",
    "main_result_move_reinit_var.fn",
    "main_exit_borrow_deref.fn",
    "main_exit_borrow_result_try.fn",
    "main_exit_assign_after_rhs_releases_borrow.fn",
    "main_exit_unwrap_assignment_after_rhs_releases_borrow.fn",
    "main_exit_plus_equals_after_rhs_releases_borrow.fn",
    "main_exit_block_borrow_release.fn",
    "main_exit_block_shadow_local.fn",
    "main_exit_if_move_then_selected.fn",
    "main_exit_logic_and_short_circuit_move_rhs.fn",
    "main_exit_try_move_result_reinit_move_again.fn",
    "invalid_use_after_drop.fn",
    "invalid_use_after_move.fn",
    "invalid_double_drop.fn",
    "invalid_double_move.fn",
    "invalid_drop_after_move.fn",
    "invalid_move_after_drop.fn",
    "invalid_self_move_assignment.fn",
    "invalid_borrow_after_move.fn",
    "invalid_move_while_borrowed.fn",
    "invalid_assign_while_borrowed.fn",
    "invalid_assign_after_rhs_still_borrowed.fn",
    "invalid_unwrap_assignment_after_rhs_still_borrowed.fn",
    "invalid_plus_equals_after_rhs_still_borrowed.fn",
    "invalid_block_reference_escape.fn",
    "invalid_block_shadow_reference_escape.fn",
    "invalid_dereference_non_reference.fn",
    "invalid_borrow_type_annotation.fn"
)) {
    if ($grammarText -notmatch [regex]::Escape($fixture)) {
        Fail-OwnershipBorrowContract ("grammar verifier missing ownership/borrow fixture: {0}" -f $fixture)
    }
}

foreach ($phrase in @(
    "use after move for identifier",
    "use after drop for identifier",
    "double drop for identifier",
    "double move for identifier",
    "cannot reinitialize moved immutable binding",
    "cannot move identifier",
    "cannot assign identifier",
    "borrow after move",
    "borrow '&' expects identifier operand",
    "dereference expects reference operand",
    "cannot leave block while identifier"
)) {
    if ($grammarText -notmatch [regex]::Escape($phrase)) {
        Fail-OwnershipBorrowContract ("grammar verifier missing ownership/borrow diagnostic phrase: {0}" -f $phrase)
    }
}

foreach ($fixture in @(
    "main_drop_unused.fn",
    "main_move_binding.fn",
    "main_move_reinit_var.fn",
    "main_result_move_reinit_var.fn",
    "main_exit_borrow_deref.fn",
    "main_exit_borrow_result_try.fn",
    "main_exit_assign_after_rhs_releases_borrow.fn",
    "main_exit_unwrap_assignment_after_rhs_releases_borrow.fn",
    "main_exit_plus_equals_after_rhs_releases_borrow.fn",
    "main_exit_block_borrow_release.fn",
    "main_exit_block_shadow_local.fn",
    "main_exit_if_move_then_selected.fn",
    "main_exit_logic_and_short_circuit_move_rhs.fn"
)) {
    if ($suiteText -notmatch [regex]::Escape($fixture)) {
        Fail-OwnershipBorrowContract ("stage0 suite missing runtime ownership/borrow fixture: {0}" -f $fixture)
    }
}

if ($suiteText -notmatch [regex]::Escape('tests/reproducibility/verify_ownership_borrow_contract.ps1')) {
    Fail-OwnershipBorrowContract "stage0 suite must call the ownership/borrow contract verifier"
}

if ($testsReadmeText -notmatch [regex]::Escape("verify_ownership_borrow_contract.ps1")) {
    Fail-OwnershipBorrowContract "tests README must document the ownership/borrow contract verifier"
}

Write-Host "Ownership/borrow contract check passed."

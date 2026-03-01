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

Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit0.fn" -ExpectedExit 0
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit7.fn" -ExpectedExit 7
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_let7.fn" -ExpectedExit 7
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_var_assign.fn" -ExpectedExit 8
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_comments.fn" -ExpectedExit 9
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_typed_u8.fn" -ExpectedExit 9
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_signature_u8.fn" -ExpectedExit 10
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_literal.fn" -ExpectedExit 11
Assert-ParseExit -RelativePath "tests/conformance/fixtures/main_exit_try_identifier.fn" -ExpectedExit 12

Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_missing_main.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_undefined_identifier.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_assign_immutable.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_unsupported_type_annotation.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_unsupported_return_annotation.fn"
Assert-ParseFail -RelativePath "tests/conformance/fixtures/invalid_try_missing_expression.fn"

Write-Host "Stage0 grammar conformance check passed."

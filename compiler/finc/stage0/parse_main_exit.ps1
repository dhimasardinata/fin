param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $SourcePath)) {
    Write-Error "Source file not found: $SourcePath"
    exit 1
}

$raw = Get-Content -Path $SourcePath -Raw

function Fail-Parse {
    param([string]$Message)
    Write-Error ("Stage0 parser rejected source: {0}. File: {1}" -f $Message, $SourcePath)
    exit 1
}

function Parse-U8Literal {
    param([string]$Text)

    $trimmed = $Text.Trim()
    if ($trimmed -notmatch '^[0-9]+$') {
        return $null
    }

    $value = 0
    if (-not [int]::TryParse($trimmed, [ref]$value)) {
        Fail-Parse "invalid integer literal '$trimmed'"
    }
    if ($value -lt 0 -or $value -gt 255) {
        Fail-Parse "exit/value literal must be in range 0..255"
    }
    return $value
}

function Parse-TypeAnnotation {
    param([string]$TypeText)

    $typeName = $TypeText.Trim()
    if ([string]::IsNullOrWhiteSpace($typeName)) {
        Fail-Parse "type annotation must not be empty"
    }

    if ($typeName -eq "u8") {
        return "u8"
    }

    Fail-Parse "unsupported type annotation '$typeName'"
}

function Parse-Expr {
    param(
        [string]$Expr,
        [hashtable]$Values,
        [hashtable]$Types
    )

    $trimmedExpr = $Expr.Trim()
    if ($trimmedExpr -match '^try\s*\(\s*(.+)\s*\)$') {
        $innerExpr = $Matches[1]
        if ([string]::IsNullOrWhiteSpace($innerExpr)) {
            Fail-Parse "try(...) requires an inner expression"
        }

        # FIP-0008 stage0 bootstrap: try(expr) currently forwards value/type.
        return Parse-Expr -Expr $innerExpr -Values $Values -Types $Types
    }

    $literal = Parse-U8Literal -Text $Expr
    if ($null -ne $literal) {
        return [pscustomobject]@{
            Type = "u8"
            Value = [int]$literal
        }
    }

    $name = $Expr.Trim()
    if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        Fail-Parse "unsupported expression '$Expr'"
    }
    if (-not $Values.ContainsKey($name)) {
        Fail-Parse "undefined identifier '$name'"
    }

    return [pscustomobject]@{
        Type = [string]$Types[$name]
        Value = [int]$Values[$name]
    }
}

# Stage0 grammar subset:
#   fn main() [-> <type>] {
#     (let|var) <ident> [: <type>] = <expr>;
#     <ident> = <expr>;
#     exit(<expr>);
#   }
# <expr> := <u8-literal> | <ident> | try(<expr>)
# <type> := u8
# with optional semicolons and line comments (# or //).
$programPattern = '(?s)^\s*fn\s+main\s*\(\s*\)\s*(?:->\s*([A-Za-z_][A-Za-z0-9_]*))?\s*\{\s*(.*?)\s*\}\s*$'
$programMatch = [regex]::Match($raw, $programPattern)
if (-not $programMatch.Success) {
    Fail-Parse "expected entrypoint pattern fn main() [-> <type>] { ... }"
}

$declaredMainReturnTypeRaw = $programMatch.Groups[1].Value
$declaredMainReturnType = if ([string]::IsNullOrWhiteSpace($declaredMainReturnTypeRaw)) {
    ""
}
else {
    Parse-TypeAnnotation -TypeText $declaredMainReturnTypeRaw
}

$body = $programMatch.Groups[2].Value
$withoutSlashComments = [regex]::Replace($body, '(?m)//.*$', '')
$withoutComments = [regex]::Replace($withoutSlashComments, '(?m)#.*$', '')
$normalized = $withoutComments -replace ';', "`n"

$statements = [System.Collections.Generic.List[string]]::new()
foreach ($line in ([regex]::Split($normalized, "`r?`n"))) {
    $stmt = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($stmt)) { continue }
    $statements.Add($stmt)
}

if ($statements.Count -eq 0) {
    Fail-Parse "function body is empty"
}

$values = @{}
$mutable = @{}
$types = @{}
$haveExit = $false
[int]$exitCode = -1

foreach ($stmt in $statements) {
    if ($haveExit) {
        Fail-Parse "statements after exit(...) are not allowed in stage0"
    }

    if ($stmt -match '^let\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([A-Za-z_][A-Za-z0-9_]*))?\s*=\s*(.+)$') {
        $name = $Matches[1]
        $declaredTypeRaw = $Matches[2]
        $expr = $Matches[3]
        if ($values.ContainsKey($name)) {
            Fail-Parse "duplicate binding '$name'"
        }

        $exprValue = Parse-Expr -Expr $expr -Values $values -Types $types
        $declaredType = if ([string]::IsNullOrWhiteSpace($declaredTypeRaw)) {
            [string]$exprValue.Type
        }
        else {
            Parse-TypeAnnotation -TypeText $declaredTypeRaw
        }
        if ([string]$exprValue.Type -ne $declaredType) {
            Fail-Parse ("type mismatch for binding '{0}': expected {1}, found {2}" -f $name, $declaredType, $exprValue.Type)
        }

        $values[$name] = [int]$exprValue.Value
        $mutable[$name] = $false
        $types[$name] = $declaredType
        continue
    }

    if ($stmt -match '^var\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([A-Za-z_][A-Za-z0-9_]*))?\s*=\s*(.+)$') {
        $name = $Matches[1]
        $declaredTypeRaw = $Matches[2]
        $expr = $Matches[3]
        if ($values.ContainsKey($name)) {
            Fail-Parse "duplicate binding '$name'"
        }

        $exprValue = Parse-Expr -Expr $expr -Values $values -Types $types
        $declaredType = if ([string]::IsNullOrWhiteSpace($declaredTypeRaw)) {
            [string]$exprValue.Type
        }
        else {
            Parse-TypeAnnotation -TypeText $declaredTypeRaw
        }
        if ([string]$exprValue.Type -ne $declaredType) {
            Fail-Parse ("type mismatch for binding '{0}': expected {1}, found {2}" -f $name, $declaredType, $exprValue.Type)
        }

        $values[$name] = [int]$exprValue.Value
        $mutable[$name] = $true
        $types[$name] = $declaredType
        continue
    }

    if ($stmt -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') {
        $name = $Matches[1]
        $expr = $Matches[2]
        if (-not $values.ContainsKey($name)) {
            Fail-Parse "assignment to undefined identifier '$name'"
        }
        if (-not [bool]$mutable[$name]) {
            Fail-Parse "cannot assign to immutable binding '$name'"
        }

        $exprValue = Parse-Expr -Expr $expr -Values $values -Types $types
        $targetType = [string]$types[$name]
        if ([string]$exprValue.Type -ne $targetType) {
            Fail-Parse ("type mismatch for assignment '{0}': expected {1}, found {2}" -f $name, $targetType, $exprValue.Type)
        }
        $values[$name] = [int]$exprValue.Value
        continue
    }

    if ($stmt -match '^exit\s*\(\s*(.+)\s*\)$') {
        $exprValue = Parse-Expr -Expr $Matches[1] -Values $values -Types $types
        $expectedExitType = if ([string]::IsNullOrWhiteSpace($declaredMainReturnType)) {
            "u8"
        }
        else {
            [string]$declaredMainReturnType
        }
        if ([string]$exprValue.Type -ne $expectedExitType) {
            Fail-Parse ("exit expression type must be {0}, found {1}" -f $expectedExitType, $exprValue.Type)
        }
        $exitCode = [int]$exprValue.Value
        $haveExit = $true
        continue
    }

    Fail-Parse "unsupported statement '$stmt'"
}

if (-not $haveExit) {
    Fail-Parse "missing exit(<expr>) statement"
}

Write-Output $exitCode

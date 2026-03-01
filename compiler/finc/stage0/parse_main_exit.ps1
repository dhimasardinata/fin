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

    $normalizedType = [regex]::Replace($typeName, '\s+', '')

    if ($normalizedType -match '^[&*]') {
        Fail-Parse "ownership/borrowing type annotations are not available in stage0 bootstrap"
    }

    if ($normalizedType -eq "u8") {
        return "u8"
    }

    if ($normalizedType -eq "Result<u8,u8>") {
        return "Result<u8,u8>"
    }

    Fail-Parse "unsupported type annotation '$typeName'"
}

function Parse-Expr {
    param(
        [string]$Expr,
        [hashtable]$Values,
        [hashtable]$Types,
        [hashtable]$ResultStates,
        [hashtable]$LifecycleStates
    )

    $trimmedExpr = $Expr.Trim()
    if ($trimmedExpr -match '^&') {
        Fail-Parse "borrow/reference expressions are not available in stage0 bootstrap"
    }
    if ($trimmedExpr -match '^\*') {
        Fail-Parse "dereference expressions are not available in stage0 bootstrap"
    }
    if ($trimmedExpr -match '^move\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)$') {
        $name = $Matches[1]
        if (-not $Values.ContainsKey($name)) {
            Fail-Parse "move for undefined identifier '$name'"
        }
        $state = [string]$LifecycleStates[$name]
        if ($state -eq "moved") {
            Fail-Parse "double move for identifier '$name'"
        }
        if ($state -eq "dropped") {
            Fail-Parse "move after drop for identifier '$name'"
        }
        if ($state -ne "alive") {
            Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $state, $name)
        }

        $LifecycleStates[$name] = "moved"
        return [pscustomobject]@{
            Type = [string]$Types[$name]
            Value = [int]$Values[$name]
            ResultState = [string]$ResultStates[$name]
        }
    }

    if ($trimmedExpr -match '^ok\s*\(\s*(.+)\s*\)$') {
        $innerExpr = $Matches[1]
        if ([string]::IsNullOrWhiteSpace($innerExpr)) {
            Fail-Parse "ok(...) requires an inner expression"
        }

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates
        if ([string]$innerValue.Type -ne "u8") {
            Fail-Parse ("ok(...) expects u8 expression in stage0, found {0}" -f $innerValue.Type)
        }

        return [pscustomobject]@{
            Type = "Result<u8,u8>"
            Value = [int]$innerValue.Value
            ResultState = "ok"
        }
    }

    if ($trimmedExpr -match '^err\s*\(\s*(.+)\s*\)$') {
        $innerExpr = $Matches[1]
        if ([string]::IsNullOrWhiteSpace($innerExpr)) {
            Fail-Parse "err(...) requires an inner expression"
        }

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates
        if ([string]$innerValue.Type -ne "u8") {
            Fail-Parse ("err(...) expects u8 expression in stage0, found {0}" -f $innerValue.Type)
        }

        return [pscustomobject]@{
            Type = "Result<u8,u8>"
            Value = [int]$innerValue.Value
            ResultState = "err"
        }
    }

    if ($trimmedExpr -match '^try\s*\(\s*(.+)\s*\)$') {
        $innerExpr = $Matches[1]
        if ([string]::IsNullOrWhiteSpace($innerExpr)) {
            Fail-Parse "try(...) requires an inner expression"
        }

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates
        if ([string]$innerValue.Type -eq "Result<u8,u8>") {
            if ([string]$innerValue.ResultState -eq "ok") {
                return [pscustomobject]@{
                    Type = "u8"
                    Value = [int]$innerValue.Value
                    ResultState = "none"
                }
            }
            if ([string]$innerValue.ResultState -eq "err") {
                Fail-Parse "try(err(...)) is not supported in stage0 bootstrap (would require hidden control flow)"
            }
            Fail-Parse "try(...) requires known result state (ok/err) in stage0 bootstrap"
        }

        Fail-Parse ("try(...) expects Result<u8,u8> in stage0 bootstrap, found {0}" -f $innerValue.Type)
    }

    $literal = Parse-U8Literal -Text $Expr
    if ($null -ne $literal) {
        return [pscustomobject]@{
            Type = "u8"
            Value = [int]$literal
            ResultState = "none"
        }
    }

    $name = $Expr.Trim()
    if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        Fail-Parse "unsupported expression '$Expr'"
    }
    if (-not $Values.ContainsKey($name)) {
        Fail-Parse "undefined identifier '$name'"
    }
    $state = [string]$LifecycleStates[$name]
    if ($state -eq "moved") {
        Fail-Parse "use after move for identifier '$name'"
    }
    if ($state -eq "dropped") {
        Fail-Parse "use after drop for identifier '$name'"
    }
    if ($state -ne "alive") {
        Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $state, $name)
    }

    return [pscustomobject]@{
        Type = [string]$Types[$name]
        Value = [int]$Values[$name]
        ResultState = [string]$ResultStates[$name]
    }
}

# Stage0 grammar subset:
#   fn main() [-> <type>] {
#     (let|var) <ident> [: <type>] = <expr>;
#     <ident> = <expr>;
#     drop(<ident>);
#     exit(<expr>);
#   }
# <expr> := <u8-literal> | <ident> | move(<ident>) | ok(<expr>) | err(<expr>) | try(<expr>)
# <type> := u8 | Result<u8,u8>
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
$resultStates = @{}
$lifecycleStates = @{}
$haveExit = $false
[int]$exitCode = -1

foreach ($stmt in $statements) {
    if ($haveExit) {
        Fail-Parse "statements after exit(...) are not allowed in stage0"
    }

    if ($stmt -match '^let\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([^=]+?))?\s*=\s*(.+)$') {
        $name = $Matches[1]
        $declaredTypeRaw = $Matches[2]
        $expr = $Matches[3]
        if ($values.ContainsKey($name)) {
            Fail-Parse "duplicate binding '$name'"
        }

        $exprValue = Parse-Expr -Expr $expr -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates
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
        $resultStates[$name] = [string]$exprValue.ResultState
        $lifecycleStates[$name] = "alive"
        continue
    }

    if ($stmt -match '^var\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([^=]+?))?\s*=\s*(.+)$') {
        $name = $Matches[1]
        $declaredTypeRaw = $Matches[2]
        $expr = $Matches[3]
        if ($values.ContainsKey($name)) {
            Fail-Parse "duplicate binding '$name'"
        }

        $exprValue = Parse-Expr -Expr $expr -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates
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
        $resultStates[$name] = [string]$exprValue.ResultState
        $lifecycleStates[$name] = "alive"
        continue
    }

    if ($stmt -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') {
        $name = $Matches[1]
        $expr = $Matches[2]
        if (-not $values.ContainsKey($name)) {
            Fail-Parse "assignment to undefined identifier '$name'"
        }
        $targetState = [string]$lifecycleStates[$name]
        if (($targetState -ne "alive") -and ($targetState -ne "moved") -and ($targetState -ne "dropped")) {
            Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $targetState, $name)
        }
        if (-not [bool]$mutable[$name]) {
            if ($targetState -eq "moved") {
                Fail-Parse "cannot reinitialize moved immutable binding '$name'"
            }
            if ($targetState -eq "dropped") {
                Fail-Parse "cannot reinitialize dropped immutable binding '$name'"
            }
            Fail-Parse "cannot assign to immutable binding '$name'"
        }

        $exprValue = Parse-Expr -Expr $expr -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates
        $postExprTargetState = [string]$lifecycleStates[$name]
        if (($targetState -eq "alive") -and (($postExprTargetState -eq "dropped") -or ($postExprTargetState -eq "moved"))) {
            Fail-Parse ("assignment target '{0}' moved or dropped during expression evaluation" -f $name)
        }
        if ($targetState -eq "alive") {
            if ($postExprTargetState -ne "alive") {
                Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $postExprTargetState, $name)
            }
        }
        elseif ($targetState -eq "moved") {
            if (($postExprTargetState -ne "moved") -and ($postExprTargetState -ne "alive")) {
                Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $postExprTargetState, $name)
            }
        }
        else {
            if (($postExprTargetState -ne "dropped") -and ($postExprTargetState -ne "alive")) {
                Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $postExprTargetState, $name)
            }
        }
        $targetType = [string]$types[$name]
        if ([string]$exprValue.Type -ne $targetType) {
            Fail-Parse ("type mismatch for assignment '{0}': expected {1}, found {2}" -f $name, $targetType, $exprValue.Type)
        }
        $values[$name] = [int]$exprValue.Value
        $resultStates[$name] = [string]$exprValue.ResultState
        $lifecycleStates[$name] = "alive"
        continue
    }

    if ($stmt -match '^drop\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)$') {
        $name = $Matches[1]
        if (-not $values.ContainsKey($name)) {
            Fail-Parse "drop for undefined identifier '$name'"
        }
        $state = [string]$lifecycleStates[$name]
        if ($state -eq "dropped") {
            Fail-Parse "double drop for identifier '$name'"
        }
        if ($state -eq "moved") {
            Fail-Parse "drop after move for identifier '$name'"
        }
        if ($state -ne "alive") {
            Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $state, $name)
        }
        $lifecycleStates[$name] = "dropped"
        continue
    }

    if ($stmt -match '^exit\s*\(\s*(.+)\s*\)$') {
        $exprValue = Parse-Expr -Expr $Matches[1] -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates
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

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

function Parse-BoolLiteral {
    param([string]$Text)

    $trimmed = $Text.Trim()
    if ($trimmed -eq "true") {
        return 1
    }
    if ($trimmed -eq "false") {
        return 0
    }
    return $null
}

function Assert-NonKeywordIdentifier {
    param([string]$Name)

    if (($Name -eq "true") -or ($Name -eq "false")) {
        Fail-Parse ("reserved keyword cannot be used as identifier '{0}'" -f $Name)
    }
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

function Copy-Hashtable {
    param([hashtable]$Table)

    $copy = @{}
    foreach ($key in $Table.Keys) {
        $copy[$key] = $Table[$key]
    }
    return $copy
}

function Split-TopLevelArguments {
    param([string]$Expr)

    $parts = [System.Collections.Generic.List[string]]::new()
    $depth = 0
    $start = 0
    for ($i = 0; $i -lt $Expr.Length; $i++) {
        $ch = $Expr[$i]
        if ($ch -eq '(') {
            $depth += 1
            continue
        }
        if ($ch -eq ')') {
            $depth -= 1
            if ($depth -lt 0) {
                Fail-Parse ("unbalanced parentheses in expression '{0}'" -f $Expr)
            }
            continue
        }
        if (($ch -eq ',') -and ($depth -eq 0)) {
            $parts.Add($Expr.Substring($start, $i - $start).Trim())
            $start = $i + 1
        }
    }

    if ($depth -ne 0) {
        Fail-Parse ("unbalanced parentheses in expression '{0}'" -f $Expr)
    }

    $parts.Add($Expr.Substring($start).Trim())
    return $parts
}

function Assert-BalancedParentheses {
    param([string]$Expr)

    $depth = 0
    for ($i = 0; $i -lt $Expr.Length; $i++) {
        $ch = $Expr[$i]
        if ($ch -eq '(') {
            $depth += 1
            continue
        }
        if ($ch -eq ')') {
            $depth -= 1
            if ($depth -lt 0) {
                Fail-Parse ("unbalanced parentheses in expression '{0}'" -f $Expr)
            }
        }
    }

    if ($depth -ne 0) {
        Fail-Parse ("unbalanced parentheses in expression '{0}'" -f $Expr)
    }
}

function Strip-OuterParentheses {
    param([string]$Expr)

    $current = $Expr.Trim()
    while ($current.StartsWith("(") -and $current.EndsWith(")")) {
        $depth = 0
        $enclosesWholeExpression = $true
        for ($i = 0; $i -lt $current.Length; $i++) {
            $ch = $current[$i]
            if ($ch -eq '(') {
                $depth += 1
                continue
            }
            if ($ch -eq ')') {
                $depth -= 1
                if ($depth -lt 0) {
                    Fail-Parse ("unbalanced parentheses in expression '{0}'" -f $Expr)
                }
                if (($depth -eq 0) -and ($i -lt ($current.Length - 1))) {
                    $enclosesWholeExpression = $false
                    break
                }
            }
        }

        if ($depth -ne 0) {
            Fail-Parse ("unbalanced parentheses in expression '{0}'" -f $Expr)
        }
        if (-not $enclosesWholeExpression) {
            break
        }

        $current = $current.Substring(1, $current.Length - 2).Trim()
        if ([string]::IsNullOrWhiteSpace($current)) {
            Fail-Parse "parenthesized expression must not be empty"
        }
    }

    return $current
}

function Find-TopLevelBinaryOperator {
    param(
        [string]$Expr,
        [string[]]$Operators
    )

    $orderedOperators = $Operators | Sort-Object { $_.Length } -Descending
    $depth = 0
    for ($i = $Expr.Length - 1; $i -ge 0; $i--) {
        $ch = $Expr[$i]
        if ($ch -eq ')') {
            $depth += 1
            continue
        }
        if ($ch -eq '(') {
            $depth -= 1
            if ($depth -lt 0) {
                Fail-Parse ("unbalanced parentheses in expression '{0}'" -f $Expr)
            }
            continue
        }
        if ($depth -eq 0) {
            foreach ($op in $orderedOperators) {
                $opLength = $op.Length
                $start = $i - $opLength + 1
                if ($start -lt 0) {
                    continue
                }
                if ($Expr.Substring($start, $opLength) -eq $op) {
                    if ($op -eq "<") {
                        if (($start -gt 0 -and $Expr[$start - 1] -eq '<') -or ((($start + 1) -lt $Expr.Length) -and $Expr[$start + 1] -eq '<')) {
                            continue
                        }
                    }
                    if ($op -eq ">") {
                        if (($start -gt 0 -and $Expr[$start - 1] -eq '>') -or ((($start + 1) -lt $Expr.Length) -and $Expr[$start + 1] -eq '>')) {
                            continue
                        }
                    }
                    return [pscustomobject]@{
                        Index = $start
                        Operator = $op
                    }
                }
            }
        }
    }

    if ($depth -ne 0) {
        Fail-Parse ("unbalanced parentheses in expression '{0}'" -f $Expr)
    }

    return $null
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
    Assert-BalancedParentheses -Expr $trimmedExpr
    $trimmedExpr = Strip-OuterParentheses -Expr $trimmedExpr

    if ($trimmedExpr -match '^&') {
        Fail-Parse "borrow/reference expressions are not available in stage0 bootstrap"
    }
    if ($trimmedExpr -match '^\*') {
        Fail-Parse "dereference expressions are not available in stage0 bootstrap"
    }
    if ($trimmedExpr -match '^if\s*\(\s*(.*)\s*\)$') {
        $argText = $Matches[1]
        if ([string]::IsNullOrWhiteSpace($argText)) {
            Fail-Parse "if(...) requires exactly 3 arguments: condition, then, else"
        }

        $parts = Split-TopLevelArguments -Expr $argText
        if ($parts.Count -ne 3) {
            Fail-Parse "if(...) requires exactly 3 arguments: condition, then, else"
        }
        foreach ($part in $parts) {
            if ([string]::IsNullOrWhiteSpace($part)) {
                Fail-Parse "if(...) arguments must not be empty"
            }
        }

        $conditionExpr = [string]$parts[0]
        $thenExpr = [string]$parts[1]
        $elseExpr = [string]$parts[2]

        $conditionValue = Parse-Expr -Expr $conditionExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates
        if ([string]$conditionValue.Type -ne "u8") {
            Fail-Parse ("if(...) condition expects u8 in stage0, found {0}" -f $conditionValue.Type)
        }

        $thenValueTypeCheck = Parse-Expr -Expr $thenExpr -Values (Copy-Hashtable -Table $Values) -Types (Copy-Hashtable -Table $Types) -ResultStates (Copy-Hashtable -Table $ResultStates) -LifecycleStates (Copy-Hashtable -Table $LifecycleStates)
        $elseValueTypeCheck = Parse-Expr -Expr $elseExpr -Values (Copy-Hashtable -Table $Values) -Types (Copy-Hashtable -Table $Types) -ResultStates (Copy-Hashtable -Table $ResultStates) -LifecycleStates (Copy-Hashtable -Table $LifecycleStates)
        if ([string]$thenValueTypeCheck.Type -ne [string]$elseValueTypeCheck.Type) {
            Fail-Parse ("if(...) branch type mismatch: then is {0}, else is {1}" -f $thenValueTypeCheck.Type, $elseValueTypeCheck.Type)
        }

        if ([int]$conditionValue.Value -ne 0) {
            return Parse-Expr -Expr $thenExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates
        }
        return Parse-Expr -Expr $elseExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates
    }

    $binaryOperator = Find-TopLevelBinaryOperator -Expr $trimmedExpr -Operators @("||")
    if ($null -eq $binaryOperator) {
        $binaryOperator = Find-TopLevelBinaryOperator -Expr $trimmedExpr -Operators @("&&")
    }
    if ($null -eq $binaryOperator) {
        $binaryOperator = Find-TopLevelBinaryOperator -Expr $trimmedExpr -Operators @("|")
    }
    if ($null -eq $binaryOperator) {
        $binaryOperator = Find-TopLevelBinaryOperator -Expr $trimmedExpr -Operators @("^")
    }
    if ($null -eq $binaryOperator) {
        $binaryOperator = Find-TopLevelBinaryOperator -Expr $trimmedExpr -Operators @("&")
    }
    if ($null -eq $binaryOperator) {
        $binaryOperator = Find-TopLevelBinaryOperator -Expr $trimmedExpr -Operators @("==", "!=", "<=", ">=", "<", ">")
    }
    if ($null -eq $binaryOperator) {
        $binaryOperator = Find-TopLevelBinaryOperator -Expr $trimmedExpr -Operators @("<<", ">>")
    }
    if ($null -eq $binaryOperator) {
        $binaryOperator = Find-TopLevelBinaryOperator -Expr $trimmedExpr -Operators @("+", "-")
    }
    if ($null -eq $binaryOperator) {
        $binaryOperator = Find-TopLevelBinaryOperator -Expr $trimmedExpr -Operators @("*", "/", "%")
    }
    if ($null -ne $binaryOperator) {
        $operatorText = [string]$binaryOperator.Operator
        $operatorLength = $operatorText.Length
        $leftExpr = $trimmedExpr.Substring(0, [int]$binaryOperator.Index).Trim()
        $rightExpr = $trimmedExpr.Substring(([int]$binaryOperator.Index + $operatorLength)).Trim()
        if ([string]::IsNullOrWhiteSpace($leftExpr) -or [string]::IsNullOrWhiteSpace($rightExpr)) {
            Fail-Parse ("binary operator '{0}' requires both operands" -f $operatorText)
        }

        $leftValue = Parse-Expr -Expr $leftExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates

        if ($operatorText -eq "&&") {
            if ([string]$leftValue.Type -ne "u8") {
                $rightProbe = Parse-Expr -Expr $rightExpr -Values (Copy-Hashtable -Table $Values) -Types (Copy-Hashtable -Table $Types) -ResultStates (Copy-Hashtable -Table $ResultStates) -LifecycleStates (Copy-Hashtable -Table $LifecycleStates)
                Fail-Parse ("operator '{0}' expects u8 operands in stage0, found {1} and {2}" -f $operatorText, $leftValue.Type, $rightProbe.Type)
            }

            if ([int]$leftValue.Value -eq 0) {
                $rightTypeCheck = Parse-Expr -Expr $rightExpr -Values (Copy-Hashtable -Table $Values) -Types (Copy-Hashtable -Table $Types) -ResultStates (Copy-Hashtable -Table $ResultStates) -LifecycleStates (Copy-Hashtable -Table $LifecycleStates)
                if ([string]$rightTypeCheck.Type -ne "u8") {
                    Fail-Parse ("operator '{0}' expects u8 operands in stage0, found {1} and {2}" -f $operatorText, $leftValue.Type, $rightTypeCheck.Type)
                }

                return [pscustomobject]@{
                    Type = "u8"
                    Value = 0
                    ResultState = "none"
                }
            }

            $rightValue = Parse-Expr -Expr $rightExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates
            if ([string]$rightValue.Type -ne "u8") {
                Fail-Parse ("operator '{0}' expects u8 operands in stage0, found {1} and {2}" -f $operatorText, $leftValue.Type, $rightValue.Type)
            }

            return [pscustomobject]@{
                Type = "u8"
                Value = if ([int]$rightValue.Value -ne 0) { 1 } else { 0 }
                ResultState = "none"
            }
        }

        if ($operatorText -eq "||") {
            if ([string]$leftValue.Type -ne "u8") {
                $rightProbe = Parse-Expr -Expr $rightExpr -Values (Copy-Hashtable -Table $Values) -Types (Copy-Hashtable -Table $Types) -ResultStates (Copy-Hashtable -Table $ResultStates) -LifecycleStates (Copy-Hashtable -Table $LifecycleStates)
                Fail-Parse ("operator '{0}' expects u8 operands in stage0, found {1} and {2}" -f $operatorText, $leftValue.Type, $rightProbe.Type)
            }

            if ([int]$leftValue.Value -ne 0) {
                $rightTypeCheck = Parse-Expr -Expr $rightExpr -Values (Copy-Hashtable -Table $Values) -Types (Copy-Hashtable -Table $Types) -ResultStates (Copy-Hashtable -Table $ResultStates) -LifecycleStates (Copy-Hashtable -Table $LifecycleStates)
                if ([string]$rightTypeCheck.Type -ne "u8") {
                    Fail-Parse ("operator '{0}' expects u8 operands in stage0, found {1} and {2}" -f $operatorText, $leftValue.Type, $rightTypeCheck.Type)
                }

                return [pscustomobject]@{
                    Type = "u8"
                    Value = 1
                    ResultState = "none"
                }
            }

            $rightValue = Parse-Expr -Expr $rightExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates
            if ([string]$rightValue.Type -ne "u8") {
                Fail-Parse ("operator '{0}' expects u8 operands in stage0, found {1} and {2}" -f $operatorText, $leftValue.Type, $rightValue.Type)
            }

            return [pscustomobject]@{
                Type = "u8"
                Value = if ([int]$rightValue.Value -ne 0) { 1 } else { 0 }
                ResultState = "none"
            }
        }

        $rightValue = Parse-Expr -Expr $rightExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates
        if (([string]$leftValue.Type -ne "u8") -or ([string]$rightValue.Type -ne "u8")) {
            Fail-Parse ("operator '{0}' expects u8 operands in stage0, found {1} and {2}" -f $operatorText, $leftValue.Type, $rightValue.Type)
        }

        $result = 0
        if ($operatorText -eq "&") {
            $result = [int]$leftValue.Value -band [int]$rightValue.Value
        }
        elseif ($operatorText -eq "^") {
            $result = [int]$leftValue.Value -bxor [int]$rightValue.Value
        }
        elseif ($operatorText -eq "|") {
            $result = [int]$leftValue.Value -bor [int]$rightValue.Value
        }
        elseif ($operatorText -eq "<<") {
            if (([int]$rightValue.Value -lt 0) -or ([int]$rightValue.Value -gt 7)) {
                Fail-Parse "shift count out of range 0..7 in '<<' expression"
            }
            $result = [int]$leftValue.Value -shl [int]$rightValue.Value
            if ($result -gt 255) {
                Fail-Parse "u8 overflow in '<<' expression"
            }
        }
        elseif ($operatorText -eq ">>") {
            if (([int]$rightValue.Value -lt 0) -or ([int]$rightValue.Value -gt 7)) {
                Fail-Parse "shift count out of range 0..7 in '>>' expression"
            }
            $result = [int]$leftValue.Value -shr [int]$rightValue.Value
        }
        elseif ($operatorText -eq "==") {
            $result = if ([int]$leftValue.Value -eq [int]$rightValue.Value) { 1 } else { 0 }
        }
        elseif ($operatorText -eq "!=") {
            $result = if ([int]$leftValue.Value -ne [int]$rightValue.Value) { 1 } else { 0 }
        }
        elseif ($operatorText -eq "<") {
            $result = if ([int]$leftValue.Value -lt [int]$rightValue.Value) { 1 } else { 0 }
        }
        elseif ($operatorText -eq "<=") {
            $result = if ([int]$leftValue.Value -le [int]$rightValue.Value) { 1 } else { 0 }
        }
        elseif ($operatorText -eq ">") {
            $result = if ([int]$leftValue.Value -gt [int]$rightValue.Value) { 1 } else { 0 }
        }
        elseif ($operatorText -eq ">=") {
            $result = if ([int]$leftValue.Value -ge [int]$rightValue.Value) { 1 } else { 0 }
        }
        elseif ($operatorText -eq "+") {
            $result = [int]$leftValue.Value + [int]$rightValue.Value
            if ($result -gt 255) {
                Fail-Parse "u8 overflow in '+' expression"
            }
        }
        elseif ($operatorText -eq "-") {
            $result = [int]$leftValue.Value - [int]$rightValue.Value
            if ($result -lt 0) {
                Fail-Parse "u8 underflow in '-' expression"
            }
        }
        elseif ($operatorText -eq "*") {
            $result = [int]$leftValue.Value * [int]$rightValue.Value
            if ($result -gt 255) {
                Fail-Parse "u8 overflow in '*' expression"
            }
        }
        elseif ($operatorText -eq "/") {
            if ([int]$rightValue.Value -eq 0) {
                Fail-Parse "division by zero in '/' expression"
            }
            $result = [int]([int]$leftValue.Value / [int]$rightValue.Value)
        }
        elseif ($operatorText -eq "%") {
            if ([int]$rightValue.Value -eq 0) {
                Fail-Parse "modulo by zero in '%' expression"
            }
            $result = [int]([int]$leftValue.Value % [int]$rightValue.Value)
        }
        else {
            Fail-Parse ("unsupported binary operator '{0}'" -f $operatorText)
        }

        return [pscustomobject]@{
            Type = "u8"
            Value = [int]$result
            ResultState = "none"
        }
    }

    if ($trimmedExpr -match '^!\s*$') {
        Fail-Parse "logical not '!' requires an operand"
    }
    if ($trimmedExpr -match '^~\s*$') {
        Fail-Parse "bitwise not '~' requires an operand"
    }
    if ($trimmedExpr.StartsWith("!")) {
        $innerExpr = $trimmedExpr.Substring(1).Trim()
        if ([string]::IsNullOrWhiteSpace($innerExpr)) {
            Fail-Parse "logical not '!' requires an operand"
        }

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates
        if ([string]$innerValue.Type -ne "u8") {
            Fail-Parse ("operator '!' expects u8 operand in stage0, found {0}" -f $innerValue.Type)
        }

        return [pscustomobject]@{
            Type = "u8"
            Value = if ([int]$innerValue.Value -eq 0) { 1 } else { 0 }
            ResultState = "none"
        }
    }
    if ($trimmedExpr.StartsWith("~")) {
        $innerExpr = $trimmedExpr.Substring(1).Trim()
        if ([string]::IsNullOrWhiteSpace($innerExpr)) {
            Fail-Parse "bitwise not '~' requires an operand"
        }

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates
        if ([string]$innerValue.Type -ne "u8") {
            Fail-Parse ("operator '~' expects u8 operand in stage0, found {0}" -f $innerValue.Type)
        }

        return [pscustomobject]@{
            Type = "u8"
            Value = [int]([int]$innerValue.Value -bxor 255)
            ResultState = "none"
        }
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

    if ($trimmedExpr -match '^ok\s*\(\s*(.*)\s*\)$') {
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

    if ($trimmedExpr -match '^err\s*\(\s*(.*)\s*\)$') {
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

    if ($trimmedExpr -match '^try\s*\(\s*(.*)\s*\)$') {
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

    $boolLiteral = Parse-BoolLiteral -Text $Expr
    if ($null -ne $boolLiteral) {
        return [pscustomobject]@{
            Type = "u8"
            Value = [int]$boolLiteral
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
# <expr> := <u8-literal> | true | false | <ident> | move(<ident>) | ok(<expr>) | err(<expr>) | try(<expr>) | if(<expr>, <expr>, <expr>) | !<expr> | (<expr>) | <expr> + <expr> | <expr> - <expr> | <expr> * <expr> | <expr> / <expr> | <expr> % <expr> | <expr> == <expr> | <expr> != <expr> | <expr> < <expr> | <expr> <= <expr> | <expr> > <expr> | <expr> >= <expr> | <expr> && <expr> | <expr> || <expr>
# <type> := u8 | Result<u8,u8>
# with optional semicolons and line comments (# or //).
$programPattern = '(?s)^\s*fn\s+main\s*\(\s*\)\s*(?:->\s*([^\{]+?))?\s*\{\s*(.*?)\s*\}\s*$'
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
if (-not [string]::IsNullOrWhiteSpace($declaredMainReturnType) -and [string]$declaredMainReturnType -ne "u8") {
    Fail-Parse ("entrypoint return type must be u8 in stage0 bootstrap, found {0}" -f $declaredMainReturnType)
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
        Assert-NonKeywordIdentifier -Name $name
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
        Assert-NonKeywordIdentifier -Name $name
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
        Assert-NonKeywordIdentifier -Name $name
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

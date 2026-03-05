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
    if ($trimmed -match '^0[bB][01]+$') {
        $binDigits = $trimmed.Substring(2)
        $value = 0
        try {
            $value = [Convert]::ToInt32($binDigits, 2)
        }
        catch {
            Fail-Parse ("invalid binary literal '{0}'" -f $trimmed)
        }

        if ($value -lt 0 -or $value -gt 255) {
            Fail-Parse "exit/value literal must be in range 0..255"
        }
        return $value
    }

    if ($trimmed -match '^0[bB]') {
        Fail-Parse ("invalid binary literal '{0}'" -f $trimmed)
    }

    if ($trimmed -match '^0[xX][0-9A-Fa-f]+$') {
        $hexDigits = $trimmed.Substring(2)
        $value = 0
        try {
            $value = [Convert]::ToInt32($hexDigits, 16)
        }
        catch {
            Fail-Parse ("invalid hex literal '{0}'" -f $trimmed)
        }

        if ($value -lt 0 -or $value -gt 255) {
            Fail-Parse "exit/value literal must be in range 0..255"
        }
        return $value
    }

    if ($trimmed -match '^0[xX]') {
        Fail-Parse ("invalid hex literal '{0}'" -f $trimmed)
    }

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

    if ($normalizedType.StartsWith("&")) {
        $inner = $normalizedType.Substring(1)
        if ($inner -eq "u8") {
            return "&u8"
        }
        if ($inner -eq "Result<u8,u8>") {
            return "&Result<u8,u8>"
        }

        Fail-Parse "unsupported type annotation '$typeName'"
    }

    if ($normalizedType.StartsWith("*")) {
        Fail-Parse "unsupported type annotation '$typeName'"
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

$script:FunctionDefinitions = @{}
$script:FunctionCallStack = [System.Collections.Generic.List[string]]::new()

function Strip-Stage0LineComments {
    param([string]$Text)

    $withoutSlashComments = [regex]::Replace($Text, '(?m)//.*$', '')
    return [regex]::Replace($withoutSlashComments, '(?m)#.*$', '')
}

function Get-Stage0Statements {
    param(
        [string]$FunctionName,
        [string]$BodyText
    )

    $normalized = $BodyText -replace ';', "`n"
    $statements = [System.Collections.Generic.List[string]]::new()
    foreach ($line in ([regex]::Split($normalized, "`r?`n"))) {
        $stmt = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($stmt)) {
            continue
        }
        $statements.Add($stmt)
    }

    if ($statements.Count -eq 0) {
        Fail-Parse ("function '{0}' body is empty" -f $FunctionName)
    }

    return $statements
}

function Get-ExpectedFunctionReturnType {
    param(
        [string]$FunctionName,
        [string]$DeclaredReturnType
    )

    if ($FunctionName -eq "main") {
        if (-not [string]::IsNullOrWhiteSpace($DeclaredReturnType) -and ([string]$DeclaredReturnType -ne "u8")) {
            Fail-Parse ("entrypoint return type must be u8 in stage0 bootstrap, found {0}" -f $DeclaredReturnType)
        }
        return "u8"
    }

    if ([string]::IsNullOrWhiteSpace($DeclaredReturnType)) {
        return "u8"
    }

    if (($DeclaredReturnType -ne "u8") -and ($DeclaredReturnType -ne "Result<u8,u8>")) {
        Fail-Parse ("function '{0}' return type must be u8 or Result<u8,u8> in stage0 bootstrap, found {1}" -f $FunctionName, $DeclaredReturnType)
    }

    return [string]$DeclaredReturnType
}

function Split-TopLevelTypeList {
    param([string]$Text)

    $parts = [System.Collections.Generic.List[string]]::new()
    $parenDepth = 0
    $angleDepth = 0
    $start = 0
    for ($i = 0; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        if ($ch -eq '(') {
            $parenDepth += 1
            continue
        }
        if ($ch -eq ')') {
            $parenDepth -= 1
            if ($parenDepth -lt 0) {
                Fail-Parse ("unbalanced parameter list '{0}'" -f $Text)
            }
            continue
        }
        if ($ch -eq '<') {
            $angleDepth += 1
            continue
        }
        if ($ch -eq '>') {
            $angleDepth -= 1
            if ($angleDepth -lt 0) {
                Fail-Parse ("unbalanced parameter list '{0}'" -f $Text)
            }
            continue
        }
        if (($ch -eq ',') -and ($parenDepth -eq 0) -and ($angleDepth -eq 0)) {
            $parts.Add($Text.Substring($start, $i - $start).Trim())
            $start = $i + 1
        }
    }

    if (($parenDepth -ne 0) -or ($angleDepth -ne 0)) {
        Fail-Parse ("unbalanced parameter list '{0}'" -f $Text)
    }

    $parts.Add($Text.Substring($start).Trim())
    return [string[]]$parts.ToArray()
}

function Parse-Stage0FunctionParameters {
    param(
        [string]$FunctionName,
        [string]$ParameterText
    )

    if ([string]::IsNullOrWhiteSpace($ParameterText)) {
        return @()
    }

    if ($FunctionName -eq "main") {
        Fail-Parse "entrypoint function 'main' does not support parameters in stage0"
    }

    $parameters = [System.Collections.Generic.List[object]]::new()
    $seenNames = @{}
    foreach ($part in @(Split-TopLevelTypeList -Text $ParameterText)) {
        $parameterDecl = [string]$part
        if ([string]::IsNullOrWhiteSpace($parameterDecl)) {
            Fail-Parse ("function '{0}' parameters must not contain empty entries" -f $FunctionName)
        }

        if ($parameterDecl -notmatch '^([A-Za-z_][A-Za-z0-9_]*)\s*:\s*(.+)$') {
            if ($parameterDecl -match '^[A-Za-z_][A-Za-z0-9_]*$') {
                Fail-Parse ("function parameter '{0}' requires explicit type annotation in stage0" -f $parameterDecl)
            }
            Fail-Parse ("invalid parameter declaration '{0}' in function '{1}'" -f $parameterDecl, $FunctionName)
        }

        $parameterName = $Matches[1]
        $parameterTypeText = $Matches[2]
        Assert-NonKeywordIdentifier -Name $parameterName
        if ($seenNames.ContainsKey($parameterName)) {
            Fail-Parse ("duplicate parameter '{0}' in function '{1}'" -f $parameterName, $FunctionName)
        }

        $parameterType = Parse-TypeAnnotation -TypeText $parameterTypeText
        if (($parameterType -ne "u8") -and ($parameterType -ne "Result<u8,u8>")) {
            Fail-Parse ("function parameter '{0}' type must be u8 or Result<u8,u8> in stage0 bootstrap, found {1}" -f $parameterName, $parameterType)
        }

        $parameters.Add([pscustomobject]@{
            Name = [string]$parameterName
            Type = [string]$parameterType
        })
        $seenNames[$parameterName] = $true
    }

    return @($parameters.ToArray())
}

function Get-Stage0FunctionDefinitions {
    param([string]$ProgramText)

    $definitions = @{}
    $sanitizedProgram = Strip-Stage0LineComments -Text $ProgramText
    $pattern = [regex]::new('(?s)\G\s*fn\s+([A-Za-z_][A-Za-z0-9_]*)\s*\((.*?)\)\s*(?:->\s*([^\{]+?))?\s*\{\s*(.*?)\s*\}\s*')
    $position = 0

    while ($position -lt $sanitizedProgram.Length) {
        if ([string]::IsNullOrWhiteSpace($sanitizedProgram.Substring($position))) {
            break
        }

        $match = $pattern.Match($sanitizedProgram, $position)
        if (-not $match.Success) {
            Fail-Parse "expected top-level function declaration in stage0 source"
        }

        $functionName = $match.Groups[1].Value
        Assert-NonKeywordIdentifier -Name $functionName
        if ($definitions.ContainsKey($functionName)) {
            Fail-Parse ("duplicate function '{0}'" -f $functionName)
        }

        $parameters = @(Parse-Stage0FunctionParameters -FunctionName $functionName -ParameterText $match.Groups[2].Value)

        $declaredReturnTypeRaw = $match.Groups[3].Value
        $declaredReturnType = if ([string]::IsNullOrWhiteSpace($declaredReturnTypeRaw)) {
            ""
        }
        else {
            Parse-TypeAnnotation -TypeText $declaredReturnTypeRaw
        }

        $expectedReturnType = Get-ExpectedFunctionReturnType -FunctionName $functionName -DeclaredReturnType $declaredReturnType
        [string[]]$statements = @(Get-Stage0Statements -FunctionName $functionName -BodyText $match.Groups[4].Value)

        $definitions[$functionName] = [pscustomobject]@{
            Name = $functionName
            Parameters = @($parameters)
            DeclaredReturnType = [string]$declaredReturnType
            ExpectedReturnType = [string]$expectedReturnType
            Statements = $statements
        }

        $position = $match.Index + $match.Length
    }

    if (($definitions.Count -eq 0) -or (-not $definitions.ContainsKey("main"))) {
        Fail-Parse "expected entrypoint pattern fn main() [-> <type>] { ... }"
    }

    return $definitions
}

function Set-ReferenceMetadata {
    param(
        [string]$Name,
        [psobject]$ExprValue,
        [hashtable]$ReferenceTargets
    )

    if (([string]$ExprValue.Type).StartsWith("&")) {
        if (-not ($ExprValue.PSObject.Properties.Name -contains "ReferenceTarget")) {
            Fail-Parse ("reference expression for binding '{0}' is missing reference target metadata" -f $Name)
        }

        $target = [string]$ExprValue.ReferenceTarget
        if ([string]::IsNullOrWhiteSpace($target)) {
            Fail-Parse ("reference expression for binding '{0}' is missing reference target metadata" -f $Name)
        }
        $ReferenceTargets[$Name] = $target
        return
    }

    if ($ReferenceTargets.ContainsKey($Name)) {
        $ReferenceTargets.Remove($Name) | Out-Null
    }
}

function Get-LiveReferenceAliasesForTarget {
    param(
        [string]$Target,
        [hashtable]$Types,
        [hashtable]$LifecycleStates,
        [hashtable]$ReferenceTargets
    )

    $aliases = [System.Collections.Generic.List[string]]::new()
    foreach ($name in ($ReferenceTargets.Keys | Sort-Object)) {
        if (-not $Types.ContainsKey($name)) {
            continue
        }
        if (-not ([string]$Types[$name]).StartsWith("&")) {
            continue
        }
        if ([string]$ReferenceTargets[$name] -ne $Target) {
            continue
        }
        if (-not $LifecycleStates.ContainsKey($name)) {
            continue
        }
        if ([string]$LifecycleStates[$name] -eq "alive") {
            $aliases.Add([string]$name)
        }
    }

    return [string[]]$aliases.ToArray()
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
        [hashtable]$LifecycleStates,
        [hashtable]$ReferenceTargets
    )

    $trimmedExpr = $Expr.Trim()
    Assert-BalancedParentheses -Expr $trimmedExpr
    $trimmedExpr = Strip-OuterParentheses -Expr $trimmedExpr

    if ($trimmedExpr -match '^&\s*$') {
        Fail-Parse "borrow '&' requires an identifier operand"
    }
    if ($trimmedExpr -match '^&\s*([A-Za-z_][A-Za-z0-9_]*)$') {
        $name = $Matches[1]
        if (-not $Values.ContainsKey($name)) {
            Fail-Parse "borrow for undefined identifier '$name'"
        }

        $state = [string]$LifecycleStates[$name]
        if ($state -eq "moved") {
            Fail-Parse "borrow after move for identifier '$name'"
        }
        if ($state -eq "dropped") {
            Fail-Parse "borrow after drop for identifier '$name'"
        }
        if ($state -ne "alive") {
            Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $state, $name)
        }

        $sourceType = [string]$Types[$name]
        if ($sourceType.StartsWith("&")) {
            Fail-Parse "nested borrow/reference expressions are not available in stage0 bootstrap"
        }

        return [pscustomobject]@{
            Type = "&$sourceType"
            Value = [int]$Values[$name]
            ResultState = [string]$ResultStates[$name]
            ReferenceTarget = $name
        }
    }
    if ($trimmedExpr.StartsWith("&")) {
        Fail-Parse "borrow '&' expects identifier operand in stage0"
    }
    if ($trimmedExpr -match '^\*\s*$') {
        Fail-Parse "dereference '*' requires an operand"
    }
    if (($trimmedExpr -match '^\*\s*([A-Za-z_][A-Za-z0-9_]*)$') -or ($trimmedExpr -match '^\*\s*\((.+)\)$')) {
        $innerExpr = $Matches[1].Trim()
        if ([string]::IsNullOrWhiteSpace($innerExpr)) {
            Fail-Parse "dereference '*' requires an operand"
        }

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
        if (-not ([string]$innerValue.Type).StartsWith("&")) {
            Fail-Parse ("dereference expects reference operand in stage0, found {0}" -f $innerValue.Type)
        }

        $innerType = [string]$innerValue.Type
        $underlyingType = $innerType.Substring(1)
        if ([string]::IsNullOrWhiteSpace($underlyingType)) {
            Fail-Parse "dereference target type must not be empty"
        }

        if ($innerValue.PSObject.Properties.Name -contains "ReferenceTarget") {
            $target = [string]$innerValue.ReferenceTarget
            if (-not [string]::IsNullOrWhiteSpace($target)) {
                if (-not $LifecycleStates.ContainsKey($target)) {
                    Fail-Parse ("dereference has unknown reference target '{0}'" -f $target)
                }
                $targetState = [string]$LifecycleStates[$target]
                if ($targetState -ne "alive") {
                    Fail-Parse ("dereference of target '{0}' is invalid because target is {1}" -f $target, $targetState)
                }

                return [pscustomobject]@{
                    Type = $underlyingType
                    Value = [int]$Values[$target]
                    ResultState = [string]$ResultStates[$target]
                    ReferenceTarget = ""
                }
            }
        }

        return [pscustomobject]@{
            Type = $underlyingType
            Value = [int]$innerValue.Value
            ResultState = [string]$innerValue.ResultState
            ReferenceTarget = ""
        }
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

        $conditionValue = Parse-Expr -Expr $conditionExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
        if ([string]$conditionValue.Type -ne "u8") {
            Fail-Parse ("if(...) condition expects u8 in stage0, found {0}" -f $conditionValue.Type)
        }

        $thenValueTypeCheck = Parse-Expr -Expr $thenExpr -Values (Copy-Hashtable -Table $Values) -Types (Copy-Hashtable -Table $Types) -ResultStates (Copy-Hashtable -Table $ResultStates) -LifecycleStates (Copy-Hashtable -Table $LifecycleStates) -ReferenceTargets (Copy-Hashtable -Table $ReferenceTargets)
        $elseValueTypeCheck = Parse-Expr -Expr $elseExpr -Values (Copy-Hashtable -Table $Values) -Types (Copy-Hashtable -Table $Types) -ResultStates (Copy-Hashtable -Table $ResultStates) -LifecycleStates (Copy-Hashtable -Table $LifecycleStates) -ReferenceTargets (Copy-Hashtable -Table $ReferenceTargets)
        if ([string]$thenValueTypeCheck.Type -ne [string]$elseValueTypeCheck.Type) {
            Fail-Parse ("if(...) branch type mismatch: then is {0}, else is {1}" -f $thenValueTypeCheck.Type, $elseValueTypeCheck.Type)
        }

        if ([int]$conditionValue.Value -ne 0) {
            return Parse-Expr -Expr $thenExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
        }
        return Parse-Expr -Expr $elseExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
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

        $leftValue = Parse-Expr -Expr $leftExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets

        if ($operatorText -eq "&&") {
            if ([string]$leftValue.Type -ne "u8") {
                $rightProbe = Parse-Expr -Expr $rightExpr -Values (Copy-Hashtable -Table $Values) -Types (Copy-Hashtable -Table $Types) -ResultStates (Copy-Hashtable -Table $ResultStates) -LifecycleStates (Copy-Hashtable -Table $LifecycleStates) -ReferenceTargets (Copy-Hashtable -Table $ReferenceTargets)
                Fail-Parse ("operator '{0}' expects u8 operands in stage0, found {1} and {2}" -f $operatorText, $leftValue.Type, $rightProbe.Type)
            }

            if ([int]$leftValue.Value -eq 0) {
                $rightTypeCheck = Parse-Expr -Expr $rightExpr -Values (Copy-Hashtable -Table $Values) -Types (Copy-Hashtable -Table $Types) -ResultStates (Copy-Hashtable -Table $ResultStates) -LifecycleStates (Copy-Hashtable -Table $LifecycleStates) -ReferenceTargets (Copy-Hashtable -Table $ReferenceTargets)
                if ([string]$rightTypeCheck.Type -ne "u8") {
                    Fail-Parse ("operator '{0}' expects u8 operands in stage0, found {1} and {2}" -f $operatorText, $leftValue.Type, $rightTypeCheck.Type)
                }

                return [pscustomobject]@{
                    Type = "u8"
                    Value = 0
                    ResultState = "none"
                }
            }

            $rightValue = Parse-Expr -Expr $rightExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
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
                $rightProbe = Parse-Expr -Expr $rightExpr -Values (Copy-Hashtable -Table $Values) -Types (Copy-Hashtable -Table $Types) -ResultStates (Copy-Hashtable -Table $ResultStates) -LifecycleStates (Copy-Hashtable -Table $LifecycleStates) -ReferenceTargets (Copy-Hashtable -Table $ReferenceTargets)
                Fail-Parse ("operator '{0}' expects u8 operands in stage0, found {1} and {2}" -f $operatorText, $leftValue.Type, $rightProbe.Type)
            }

            if ([int]$leftValue.Value -ne 0) {
                $rightTypeCheck = Parse-Expr -Expr $rightExpr -Values (Copy-Hashtable -Table $Values) -Types (Copy-Hashtable -Table $Types) -ResultStates (Copy-Hashtable -Table $ResultStates) -LifecycleStates (Copy-Hashtable -Table $LifecycleStates) -ReferenceTargets (Copy-Hashtable -Table $ReferenceTargets)
                if ([string]$rightTypeCheck.Type -ne "u8") {
                    Fail-Parse ("operator '{0}' expects u8 operands in stage0, found {1} and {2}" -f $operatorText, $leftValue.Type, $rightTypeCheck.Type)
                }

                return [pscustomobject]@{
                    Type = "u8"
                    Value = 1
                    ResultState = "none"
                }
            }

            $rightValue = Parse-Expr -Expr $rightExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
            if ([string]$rightValue.Type -ne "u8") {
                Fail-Parse ("operator '{0}' expects u8 operands in stage0, found {1} and {2}" -f $operatorText, $leftValue.Type, $rightValue.Type)
            }

            return [pscustomobject]@{
                Type = "u8"
                Value = if ([int]$rightValue.Value -ne 0) { 1 } else { 0 }
                ResultState = "none"
            }
        }

        $rightValue = Parse-Expr -Expr $rightExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
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

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
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

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
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

        $moveType = [string]$Types[$name]
        if (-not $moveType.StartsWith("&")) {
            $activeBorrowers = @(Get-LiveReferenceAliasesForTarget -Target $name -Types $Types -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets)
            if ($activeBorrowers.Count -gt 0) {
                Fail-Parse ("cannot move identifier '{0}' while borrowed by '{1}'" -f $name, [string]$activeBorrowers[0])
            }
        }

        $moveValue = [int]$Values[$name]
        $moveResultState = [string]$ResultStates[$name]
        $moveReferenceTarget = ""
        if ($moveType.StartsWith("&")) {
            if (-not $ReferenceTargets.ContainsKey($name)) {
                Fail-Parse ("reference binding '{0}' is missing target metadata" -f $name)
            }

            $target = [string]$ReferenceTargets[$name]
            if ([string]::IsNullOrWhiteSpace($target)) {
                Fail-Parse ("reference binding '{0}' is missing target metadata" -f $name)
            }
            if (-not $LifecycleStates.ContainsKey($target)) {
                Fail-Parse ("reference binding '{0}' points to unknown target '{1}'" -f $name, $target)
            }

            $targetState = [string]$LifecycleStates[$target]
            if ($targetState -ne "alive") {
                Fail-Parse ("reference target '{0}' is not alive for binding '{1}' (state: {2})" -f $target, $name, $targetState)
            }

            $moveValue = [int]$Values[$target]
            $moveResultState = [string]$ResultStates[$target]
            $moveReferenceTarget = $target
        }

        $LifecycleStates[$name] = "moved"
        return [pscustomobject]@{
            Type = $moveType
            Value = $moveValue
            ResultState = $moveResultState
            ReferenceTarget = $moveReferenceTarget
        }
    }

    if ($trimmedExpr -match '^ok\s*\(\s*(.*)\s*\)$') {
        $innerExpr = $Matches[1]
        if ([string]::IsNullOrWhiteSpace($innerExpr)) {
            Fail-Parse "ok(...) requires an inner expression"
        }

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
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

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
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

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
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

    if ($trimmedExpr -eq "try") {
        Fail-Parse "try keyword requires expression"
    }

    if ($trimmedExpr -match '^try\s+(.+)$') {
        $innerExpr = $Matches[1].Trim()
        if ([string]::IsNullOrWhiteSpace($innerExpr)) {
            Fail-Parse "try keyword requires expression"
        }

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
        if ([string]$innerValue.Type -eq "Result<u8,u8>") {
            if ([string]$innerValue.ResultState -eq "ok") {
                return [pscustomobject]@{
                    Type = "u8"
                    Value = [int]$innerValue.Value
                    ResultState = "none"
                }
            }
            if ([string]$innerValue.ResultState -eq "err") {
                Fail-Parse "try keyword on err(...) is not supported in stage0 bootstrap (would require hidden control flow)"
            }
            Fail-Parse "try keyword requires known result state (ok/err) in stage0 bootstrap"
        }

        Fail-Parse ("try keyword expects Result<u8,u8> in stage0 bootstrap, found {0}" -f $innerValue.Type)
    }

    if ($trimmedExpr.EndsWith("?")) {
        $innerExpr = $trimmedExpr.Substring(0, $trimmedExpr.Length - 1).Trim()
        if ([string]::IsNullOrWhiteSpace($innerExpr)) {
            Fail-Parse "postfix '?' requires an operand"
        }

        $innerValue = Parse-Expr -Expr $innerExpr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
        if ([string]$innerValue.Type -eq "Result<u8,u8>") {
            if ([string]$innerValue.ResultState -eq "ok") {
                return [pscustomobject]@{
                    Type = "u8"
                    Value = [int]$innerValue.Value
                    ResultState = "none"
                }
            }
            if ([string]$innerValue.ResultState -eq "err") {
                Fail-Parse "postfix '?' on err(...) is not supported in stage0 bootstrap (would require hidden control flow)"
            }
            Fail-Parse "postfix '?' requires known result state (ok/err) in stage0 bootstrap"
        }

        Fail-Parse ("postfix '?' expects Result<u8,u8> in stage0 bootstrap, found {0}" -f $innerValue.Type)
    }

    if ($trimmedExpr -match '^([A-Za-z_][A-Za-z0-9_]*)\s*\((.*)\)$') {
        $functionName = $Matches[1]
        $argText = $Matches[2].Trim()
        if ($functionName -eq "main") {
            Fail-Parse "entrypoint function 'main' cannot be called as expression in stage0"
        }
        if (-not $script:FunctionDefinitions.ContainsKey($functionName)) {
            Fail-Parse ("undefined function '{0}'" -f $functionName)
        }

        $definition = $script:FunctionDefinitions[$functionName]
        $argumentExprs = @()
        if (-not [string]::IsNullOrWhiteSpace($argText)) {
            $argumentExprs = @(Split-TopLevelArguments -Expr $argText)
            foreach ($argumentExpr in $argumentExprs) {
                if ([string]::IsNullOrWhiteSpace([string]$argumentExpr)) {
                    Fail-Parse ("function call '{0}' arguments must not be empty" -f $functionName)
                }
            }
        }

        if ($argumentExprs.Count -ne $definition.Parameters.Count) {
            Fail-Parse ("function call '{0}' expects {1} arguments, found {2}" -f $functionName, $definition.Parameters.Count, $argumentExprs.Count)
        }

        $argumentValues = [System.Collections.Generic.List[object]]::new()
        foreach ($argumentExpr in $argumentExprs) {
            $argumentValues.Add((Parse-Expr -Expr ([string]$argumentExpr) -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets))
        }

        $callValue = Invoke-Stage0Function -FunctionName $functionName -ArgumentValues @($argumentValues.ToArray())
        return [pscustomobject]@{
            Type = [string]$callValue.Type
            Value = [int]$callValue.Value
            ResultState = [string]$callValue.ResultState
            ReferenceTarget = ""
        }
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

    $resolvedType = [string]$Types[$name]
    $resolvedValue = [int]$Values[$name]
    $resolvedResultState = [string]$ResultStates[$name]
    $resolvedReferenceTarget = ""
    if ($resolvedType.StartsWith("&")) {
        if (-not $ReferenceTargets.ContainsKey($name)) {
            Fail-Parse ("reference binding '{0}' is missing target metadata" -f $name)
        }

        $target = [string]$ReferenceTargets[$name]
        if ([string]::IsNullOrWhiteSpace($target)) {
            Fail-Parse ("reference binding '{0}' is missing target metadata" -f $name)
        }
        if (-not $LifecycleStates.ContainsKey($target)) {
            Fail-Parse ("reference binding '{0}' points to unknown target '{1}'" -f $name, $target)
        }

        $targetState = [string]$LifecycleStates[$target]
        if ($targetState -ne "alive") {
            Fail-Parse ("reference target '{0}' is not alive for binding '{1}' (state: {2})" -f $target, $name, $targetState)
        }

        $resolvedValue = [int]$Values[$target]
        $resolvedResultState = [string]$ResultStates[$target]
        $resolvedReferenceTarget = $target
    }

    return [pscustomobject]@{
        Type = $resolvedType
        Value = $resolvedValue
        ResultState = $resolvedResultState
        ReferenceTarget = $resolvedReferenceTarget
    }
}

function Invoke-Stage0Function {
    param(
        [string]$FunctionName,
        [object[]]$ArgumentValues = @()
    )

    if (-not $script:FunctionDefinitions.ContainsKey($FunctionName)) {
        Fail-Parse ("undefined function '{0}'" -f $FunctionName)
    }

    if ($script:FunctionCallStack.Contains($FunctionName)) {
        $callChain = @($script:FunctionCallStack.ToArray()) + $FunctionName
        Fail-Parse ("recursive function call is not supported in stage0: {0}" -f ([string]::Join(' -> ', $callChain)))
    }

    $definition = $script:FunctionDefinitions[$FunctionName]
    if ($ArgumentValues.Count -ne $definition.Parameters.Count) {
        Fail-Parse ("function call '{0}' expects {1} arguments, found {2}" -f $FunctionName, $definition.Parameters.Count, $ArgumentValues.Count)
    }

    $script:FunctionCallStack.Add($FunctionName) | Out-Null

    try {
        $values = @{}
        $mutable = @{}
        $types = @{}
        $resultStates = @{}
        $lifecycleStates = @{}
        $referenceTargets = @{}
        $haveTerminal = $false
        $functionResult = $null

        for ($i = 0; $i -lt $definition.Parameters.Count; $i++) {
            $parameter = $definition.Parameters[$i]
            $argumentValue = $ArgumentValues[$i]
            if ([string]$argumentValue.Type -ne [string]$parameter.Type) {
                Fail-Parse ("type mismatch for parameter '{0}' in function '{1}': expected {2}, found {3}" -f $parameter.Name, $FunctionName, $parameter.Type, $argumentValue.Type)
            }

            $values[$parameter.Name] = [int]$argumentValue.Value
            $mutable[$parameter.Name] = $false
            $types[$parameter.Name] = [string]$parameter.Type
            $resultStates[$parameter.Name] = [string]$argumentValue.ResultState
            $lifecycleStates[$parameter.Name] = 'alive'
        }

        foreach ($stmt in $definition.Statements) {
            if ($haveTerminal) {
                Fail-Parse 'statements after terminal exit/return are not allowed in stage0'
            }

            if ($stmt -match '^let\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([^?=]+?))?\s*\?=\s*$') {
                Fail-Parse 'unwrap binding requires expression'
            }

            if ($stmt -match '^let\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([^?=]+?))?\s*\?=\s*(.+)$') {
                $name = $Matches[1]
                Assert-NonKeywordIdentifier -Name $name
                $declaredTypeRaw = $Matches[2]
                $expr = $Matches[3]
                if ($values.ContainsKey($name)) {
                    Fail-Parse "duplicate binding '$name'"
                }

                $exprValue = Parse-Expr -Expr ('try ' + $expr) -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets
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
                $lifecycleStates[$name] = 'alive'
                Set-ReferenceMetadata -Name $name -ExprValue $exprValue -ReferenceTargets $referenceTargets
                continue
            }

            if ($stmt -match '^let\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([^=]+?))?\s*=\s*(.+)$') {
                $name = $Matches[1]
                Assert-NonKeywordIdentifier -Name $name
                $declaredTypeRaw = $Matches[2]
                $expr = $Matches[3]
                if ($values.ContainsKey($name)) {
                    Fail-Parse "duplicate binding '$name'"
                }

                $exprValue = Parse-Expr -Expr $expr -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets
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
                $lifecycleStates[$name] = 'alive'
                Set-ReferenceMetadata -Name $name -ExprValue $exprValue -ReferenceTargets $referenceTargets
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

                $exprValue = Parse-Expr -Expr $expr -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets
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
                $lifecycleStates[$name] = 'alive'
                Set-ReferenceMetadata -Name $name -ExprValue $exprValue -ReferenceTargets $referenceTargets
                continue
            }

            if ($stmt -match '^var\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([^?=]+?))?\s*\?=\s*$') {
                Fail-Parse 'unwrap var binding requires expression'
            }

            if ($stmt -match '^var\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([^?=]+?))?\s*\?=\s*(.+)$') {
                $name = $Matches[1]
                Assert-NonKeywordIdentifier -Name $name
                $declaredTypeRaw = $Matches[2]
                $expr = $Matches[3]
                if ($values.ContainsKey($name)) {
                    Fail-Parse "duplicate binding '$name'"
                }

                $exprValue = Parse-Expr -Expr ('try ' + $expr) -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets
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
                $lifecycleStates[$name] = 'alive'
                Set-ReferenceMetadata -Name $name -ExprValue $exprValue -ReferenceTargets $referenceTargets
                continue
            }

            if ($stmt -match '^([A-Za-z_][A-Za-z0-9_]*)\s*\?=\s*$') {
                Fail-Parse 'unwrap assignment requires expression'
            }

            if ($stmt -match '^([A-Za-z_][A-Za-z0-9_]*)\s*\+=\s*$') {
                Fail-Parse "compound assignment '+=' requires expression"
            }

            if ($stmt -match '^([A-Za-z_][A-Za-z0-9_]*)\s*\+=\s*(.+)$') {
                $name = $Matches[1]
                Assert-NonKeywordIdentifier -Name $name
                $expr = $Matches[2]
                if (-not $values.ContainsKey($name)) {
                    Fail-Parse "assignment to undefined identifier '$name'"
                }

                $targetState = [string]$lifecycleStates[$name]
                if ($targetState -eq 'moved') {
                    Fail-Parse ("compound assignment '+=' requires alive binding '{0}', found moved" -f $name)
                }
                if ($targetState -eq 'dropped') {
                    Fail-Parse ("compound assignment '+=' requires alive binding '{0}', found dropped" -f $name)
                }
                if ($targetState -ne 'alive') {
                    Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $targetState, $name)
                }

                if (-not [bool]$mutable[$name]) {
                    Fail-Parse "cannot assign to immutable binding '$name'"
                }

                $exprValue = Parse-Expr -Expr $expr -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets
                $postExprTargetState = [string]$lifecycleStates[$name]
                if (($postExprTargetState -eq 'dropped') -or ($postExprTargetState -eq 'moved')) {
                    Fail-Parse ("assignment target '{0}' moved or dropped during expression evaluation" -f $name)
                }
                if ($postExprTargetState -ne 'alive') {
                    Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $postExprTargetState, $name)
                }

                $targetType = [string]$types[$name]
                if ($targetType -ne 'u8') {
                    Fail-Parse ("compound assignment '+=' expects u8 target in stage0, found {0}" -f $targetType)
                }
                if ([string]$exprValue.Type -ne 'u8') {
                    Fail-Parse ("compound assignment '+=' expects u8 expression in stage0, found {0}" -f $exprValue.Type)
                }

                $activeBorrowers = @(Get-LiveReferenceAliasesForTarget -Target $name -Types $types -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets)
                if ($activeBorrowers.Count -gt 0) {
                    Fail-Parse ("cannot assign identifier '{0}' while borrowed by '{1}'" -f $name, [string]$activeBorrowers[0])
                }

                $result = [int]$values[$name] + [int]$exprValue.Value
                if ($result -gt 255) {
                    Fail-Parse "u8 overflow in '+=' expression"
                }

                $values[$name] = $result
                $resultStates[$name] = 'none'
                $lifecycleStates[$name] = 'alive'
                continue
            }

            if ($stmt -match '^([A-Za-z_][A-Za-z0-9_]*)\s*\?=\s*(.+)$') {
                $name = $Matches[1]
                Assert-NonKeywordIdentifier -Name $name
                $expr = $Matches[2]
                if (-not $values.ContainsKey($name)) {
                    Fail-Parse "assignment to undefined identifier '$name'"
                }
                $targetState = [string]$lifecycleStates[$name]
                if (($targetState -ne 'alive') -and ($targetState -ne 'moved') -and ($targetState -ne 'dropped')) {
                    Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $targetState, $name)
                }
                if (-not [bool]$mutable[$name]) {
                    if ($targetState -eq 'moved') {
                        Fail-Parse "cannot reinitialize moved immutable binding '$name'"
                    }
                    if ($targetState -eq 'dropped') {
                        Fail-Parse "cannot reinitialize dropped immutable binding '$name'"
                    }
                    Fail-Parse "cannot assign to immutable binding '$name'"
                }
                $exprValue = Parse-Expr -Expr ('try ' + $expr) -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets
                $postExprTargetState = [string]$lifecycleStates[$name]
                if (($targetState -eq 'alive') -and (($postExprTargetState -eq 'dropped') -or ($postExprTargetState -eq 'moved'))) {
                    Fail-Parse ("assignment target '{0}' moved or dropped during expression evaluation" -f $name)
                }
                if ($targetState -eq 'alive') {
                    if ($postExprTargetState -ne 'alive') {
                        Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $postExprTargetState, $name)
                    }
                }
                elseif ($targetState -eq 'moved') {
                    if (($postExprTargetState -ne 'moved') -and ($postExprTargetState -ne 'alive')) {
                        Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $postExprTargetState, $name)
                    }
                }
                else {
                    if (($postExprTargetState -ne 'dropped') -and ($postExprTargetState -ne 'alive')) {
                        Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $postExprTargetState, $name)
                    }
                }
                $targetType = [string]$types[$name]
                if (-not $targetType.StartsWith('&')) {
                    $activeBorrowers = @(Get-LiveReferenceAliasesForTarget -Target $name -Types $types -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets)
                    if ($activeBorrowers.Count -gt 0) {
                        Fail-Parse ("cannot assign identifier '{0}' while borrowed by '{1}'" -f $name, [string]$activeBorrowers[0])
                    }
                }
                if ([string]$exprValue.Type -ne $targetType) {
                    Fail-Parse ("type mismatch for assignment '{0}': expected {1}, found {2}" -f $name, $targetType, $exprValue.Type)
                }
                $values[$name] = [int]$exprValue.Value
                $resultStates[$name] = [string]$exprValue.ResultState
                $lifecycleStates[$name] = 'alive'
                Set-ReferenceMetadata -Name $name -ExprValue $exprValue -ReferenceTargets $referenceTargets
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
                if (($targetState -ne 'alive') -and ($targetState -ne 'moved') -and ($targetState -ne 'dropped')) {
                    Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $targetState, $name)
                }
                if (-not [bool]$mutable[$name]) {
                    if ($targetState -eq 'moved') {
                        Fail-Parse "cannot reinitialize moved immutable binding '$name'"
                    }
                    if ($targetState -eq 'dropped') {
                        Fail-Parse "cannot reinitialize dropped immutable binding '$name'"
                    }
                    Fail-Parse "cannot assign to immutable binding '$name'"
                }
                $exprValue = Parse-Expr -Expr $expr -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets
                $postExprTargetState = [string]$lifecycleStates[$name]
                if (($targetState -eq 'alive') -and (($postExprTargetState -eq 'dropped') -or ($postExprTargetState -eq 'moved'))) {
                    Fail-Parse ("assignment target '{0}' moved or dropped during expression evaluation" -f $name)
                }
                if ($targetState -eq 'alive') {
                    if ($postExprTargetState -ne 'alive') {
                        Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $postExprTargetState, $name)
                    }
                }
                elseif ($targetState -eq 'moved') {
                    if (($postExprTargetState -ne 'moved') -and ($postExprTargetState -ne 'alive')) {
                        Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $postExprTargetState, $name)
                    }
                }
                else {
                    if (($postExprTargetState -ne 'dropped') -and ($postExprTargetState -ne 'alive')) {
                        Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $postExprTargetState, $name)
                    }
                }
                $targetType = [string]$types[$name]
                if (-not $targetType.StartsWith('&')) {
                    $activeBorrowers = @(Get-LiveReferenceAliasesForTarget -Target $name -Types $types -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets)
                    if ($activeBorrowers.Count -gt 0) {
                        Fail-Parse ("cannot assign identifier '{0}' while borrowed by '{1}'" -f $name, [string]$activeBorrowers[0])
                    }
                }
                if ([string]$exprValue.Type -ne $targetType) {
                    Fail-Parse ("type mismatch for assignment '{0}': expected {1}, found {2}" -f $name, $targetType, $exprValue.Type)
                }
                $values[$name] = [int]$exprValue.Value
                $resultStates[$name] = [string]$exprValue.ResultState
                $lifecycleStates[$name] = 'alive'
                Set-ReferenceMetadata -Name $name -ExprValue $exprValue -ReferenceTargets $referenceTargets
                continue
            }

            if ($stmt -match '^drop\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)$') {
                $name = $Matches[1]
                if (-not $values.ContainsKey($name)) {
                    Fail-Parse "drop for undefined identifier '$name'"
                }
                $state = [string]$lifecycleStates[$name]
                if ($state -eq 'dropped') {
                    Fail-Parse "double drop for identifier '$name'"
                }
                if ($state -eq 'moved') {
                    Fail-Parse "drop after move for identifier '$name'"
                }
                if ($state -ne 'alive') {
                    Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $state, $name)
                }

                $dropType = [string]$types[$name]
                if (-not $dropType.StartsWith('&')) {
                    $activeBorrowers = @(Get-LiveReferenceAliasesForTarget -Target $name -Types $types -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets)
                    if ($activeBorrowers.Count -gt 0) {
                        Fail-Parse ("cannot drop identifier '{0}' while borrowed by '{1}'" -f $name, [string]$activeBorrowers[0])
                    }
                }

                $lifecycleStates[$name] = 'dropped'
                continue
            }

            if ($stmt -match '^exit\s*\(\s*(.+)\s*\)$') {
                if ($FunctionName -ne 'main') {
                    Fail-Parse ("exit(...) is only allowed in entrypoint function 'main', found in function '{0}'" -f $FunctionName)
                }

                $exprValue = Parse-Expr -Expr $Matches[1] -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets
                if ([string]$exprValue.Type -ne [string]$definition.ExpectedReturnType) {
                    Fail-Parse ("exit expression type must be {0}, found {1}" -f $definition.ExpectedReturnType, $exprValue.Type)
                }

                $functionResult = [pscustomobject]@{
                    Type = [string]$definition.ExpectedReturnType
                    Value = [int]$exprValue.Value
                    ResultState = [string]$exprValue.ResultState
                }
                $haveTerminal = $true
                continue
            }

            if (($stmt -match '^return\s*$') -or ($stmt -match '^return\s*\(\s*\)\s*$')) {
                Fail-Parse 'return statement requires expression'
            }

            if (($stmt -match '^return\s+(.+)$') -or ($stmt -match '^return\s*\(\s*(.+)\s*\)$')) {
                $exprValue = Parse-Expr -Expr $Matches[1] -Values $values -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets
                if ([string]$exprValue.Type -ne [string]$definition.ExpectedReturnType) {
                    Fail-Parse ("return expression type must be {0}, found {1}" -f $definition.ExpectedReturnType, $exprValue.Type)
                }

                $functionResult = [pscustomobject]@{
                    Type = [string]$definition.ExpectedReturnType
                    Value = [int]$exprValue.Value
                    ResultState = [string]$exprValue.ResultState
                }
                $haveTerminal = $true
                continue
            }

            Fail-Parse "unsupported statement '$stmt'"
        }

        if (-not $haveTerminal) {
            if ($FunctionName -eq 'main') {
                Fail-Parse 'missing terminal statement (exit(<expr>) or return <expr>)'
            }
            Fail-Parse ("function '{0}' is missing terminal return" -f $FunctionName)
        }

        return $functionResult
    }
    finally {
        if ($script:FunctionCallStack.Count -gt 0) {
            $script:FunctionCallStack.RemoveAt($script:FunctionCallStack.Count - 1)
        }
    }
}

# Stage0 grammar subset:
#   fn <name>([<param> [, <param>]*]) [-> <type>] {
#     (let|var) <ident> [: <type>] = <expr>;
#     let <ident> [: <type>] ?= <expr>;
#     var <ident> [: <type>] ?= <expr>;
#     <ident> ?= <expr>;
#     <ident> += <expr>;
#     <ident> = <expr>;
#     drop(<ident>);
#     exit(<expr>);
#     return <expr>;
#   }
# <param> := <ident> : (u8 | Result<u8,u8>)
# <expr> := <u8-literal> | true | false | <ident> | <name>([<expr> [, <expr>]*]) | &<ident> | *<expr> | move(<ident>) | ok(<expr>) | err(<expr>) | try(<expr>) | try <expr> | <expr>? | if(<expr>, <expr>, <expr>) | !<expr> | (<expr>) | <expr> + <expr> | <expr> - <expr> | <expr> * <expr> | <expr> / <expr> | <expr> % <expr> | <expr> == <expr> | <expr> != <expr> | <expr> < <expr> | <expr> <= <expr> | <expr> > <expr> | <expr> >= <expr> | <expr> && <expr> | <expr> || <expr>
# <type> := u8 | Result<u8,u8> | &u8 | &Result<u8,u8>
# with optional semicolons and line comments (# or //).
$script:FunctionDefinitions = Get-Stage0FunctionDefinitions -ProgramText $raw
$mainResult = Invoke-Stage0Function -FunctionName 'main'
Write-Output ([int]$mainResult.Value)

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
$script:Stage0BindingCounter = 0
$script:Stage0ScopeFrames = [System.Collections.Generic.List[hashtable]]::new()
$script:Stage0BindingDisplayNames = @{}

function New-Stage0BindingKey {
    param([string]$Name)

    $script:Stage0BindingCounter += 1
    return ("{0}#{1}" -f $Name, $script:Stage0BindingCounter)
}

function Push-Stage0ScopeFrame {
    $frame = @{}
    $script:Stage0ScopeFrames.Add($frame) | Out-Null
    return $frame
}

function Pop-Stage0ScopeFrame {
    if ($script:Stage0ScopeFrames.Count -eq 0) {
        Fail-Parse "internal stage0 scope stack underflow"
    }

    $lastIndex = $script:Stage0ScopeFrames.Count - 1
    $frame = $script:Stage0ScopeFrames[$lastIndex]
    $script:Stage0ScopeFrames.RemoveAt($lastIndex)
    return $frame
}

function Get-CurrentStage0ScopeFrame {
    if ($script:Stage0ScopeFrames.Count -eq 0) {
        return $null
    }

    return $script:Stage0ScopeFrames[$script:Stage0ScopeFrames.Count - 1]
}

function Resolve-Stage0BindingKey {
    param([string]$Name)

    for ($i = $script:Stage0ScopeFrames.Count - 1; $i -ge 0; $i--) {
        $frame = $script:Stage0ScopeFrames[$i]
        if ($frame.ContainsKey($Name)) {
            return [string]$frame[$Name]
        }
    }

    return $null
}

function Resolve-Stage0BindingKeyOrFail {
    param(
        [string]$Name,
        [string]$UndefinedMessage
    )

    $bindingKey = Resolve-Stage0BindingKey -Name $Name
    if ([string]::IsNullOrWhiteSpace($bindingKey)) {
        Fail-Parse $UndefinedMessage
    }

    return [string]$bindingKey
}

function Get-Stage0BindingDisplayName {
    param([string]$BindingKey)

    if ([string]::IsNullOrWhiteSpace($BindingKey)) {
        return ""
    }

    if ($script:Stage0BindingDisplayNames.ContainsKey($BindingKey)) {
        return [string]$script:Stage0BindingDisplayNames[$BindingKey]
    }

    return [string]$BindingKey
}

function New-Stage0Binding {
    param(
        [string]$Name,
        [bool]$IsMutable,
        [string]$DeclaredType,
        [psobject]$ExprValue,
        [hashtable]$Values,
        [hashtable]$Mutable,
        [hashtable]$Types,
        [hashtable]$ResultStates,
        [hashtable]$LifecycleStates,
        [hashtable]$ReferenceTargets
    )

    $frame = Get-CurrentStage0ScopeFrame
    if ($null -eq $frame) {
        Fail-Parse ("internal stage0 scope missing for binding '{0}'" -f $Name)
    }
    if ($frame.ContainsKey($Name)) {
        Fail-Parse "duplicate binding '$Name'"
    }

    $bindingKey = New-Stage0BindingKey -Name $Name
    $frame[$Name] = $bindingKey
    $script:Stage0BindingDisplayNames[$bindingKey] = $Name

    $Values[$bindingKey] = [int]$ExprValue.Value
    $Mutable[$bindingKey] = $IsMutable
    $Types[$bindingKey] = [string]$DeclaredType
    $ResultStates[$bindingKey] = [string]$ExprValue.ResultState
    $LifecycleStates[$bindingKey] = 'alive'
    Set-ReferenceMetadata -BindingKey $bindingKey -ExprValue $ExprValue -ReferenceTargets $ReferenceTargets
    return [string]$bindingKey
}

function Get-Stage0ReferenceTargetKey {
    param(
        [string]$BindingKey,
        [hashtable]$ReferenceTargets,
        [hashtable]$LifecycleStates
    )

    $bindingName = Get-Stage0BindingDisplayName -BindingKey $BindingKey
    if (-not $ReferenceTargets.ContainsKey($BindingKey)) {
        Fail-Parse ("reference binding '{0}' is missing target metadata" -f $bindingName)
    }

    $targetKey = [string]$ReferenceTargets[$BindingKey]
    if ([string]::IsNullOrWhiteSpace($targetKey)) {
        Fail-Parse ("reference binding '{0}' is missing target metadata" -f $bindingName)
    }

    $targetName = Get-Stage0BindingDisplayName -BindingKey $targetKey
    if (-not $LifecycleStates.ContainsKey($targetKey)) {
        Fail-Parse ("reference binding '{0}' points to unknown target '{1}'" -f $bindingName, $targetName)
    }

    return [string]$targetKey
}

function Strip-Stage0LineComments {
    param([string]$Text)

    $withoutSlashComments = [regex]::Replace($Text, '(?m)//.*$', '')
    return [regex]::Replace($withoutSlashComments, '(?m)#.*$', '')
}

function Skip-Stage0Whitespace {
    param(
        [string]$Text,
        [int]$StartIndex
    )

    $position = $StartIndex
    while (($position -lt $Text.Length) -and [char]::IsWhiteSpace($Text[$position])) {
        $position += 1
    }

    return $position
}

function Get-MatchingDelimiterIndex {
    param(
        [string]$Text,
        [int]$StartIndex,
        [char]$OpenChar,
        [char]$CloseChar,
        [string]$ContextDescription
    )

    if (($StartIndex -lt 0) -or ($StartIndex -ge $Text.Length) -or ($Text[$StartIndex] -ne $OpenChar)) {
        Fail-Parse ("expected '{0}' to start {1}" -f $OpenChar, $ContextDescription)
    }

    $depth = 0
    for ($i = $StartIndex; $i -lt $Text.Length; $i++) {
        $ch = $Text[$i]
        if ($ch -eq $OpenChar) {
            $depth += 1
            continue
        }
        if ($ch -eq $CloseChar) {
            $depth -= 1
            if ($depth -lt 0) {
                Fail-Parse ("unbalanced {0}" -f $ContextDescription)
            }
            if ($depth -eq 0) {
                return $i
            }
        }
    }

    Fail-Parse ("unterminated {0}" -f $ContextDescription)
}

function Get-Stage0Statements {
    param(
        [string]$FunctionName,
        [string]$BodyText,
        [switch]$AllowEmpty
    )

    $statements = [System.Collections.Generic.List[string]]::new()
    $parenDepth = 0
    $braceDepth = 0
    $start = 0

    for ($i = 0; $i -lt $BodyText.Length; $i++) {
        $ch = $BodyText[$i]
        if ($ch -eq '(') {
            $parenDepth += 1
            continue
        }
        if ($ch -eq ')') {
            $parenDepth -= 1
            if ($parenDepth -lt 0) {
                Fail-Parse ("unbalanced parentheses in function '{0}' body" -f $FunctionName)
            }
            continue
        }
        if ($ch -eq '{') {
            $braceDepth += 1
            continue
        }
        if ($ch -eq '}') {
            $braceDepth -= 1
            if ($braceDepth -lt 0) {
                Fail-Parse ("unbalanced block braces in function '{0}' body" -f $FunctionName)
            }
            continue
        }

        $isStatementBreak = (($ch -eq ';') -or ($ch -eq "`n") -or ($ch -eq "`r"))
        if ($isStatementBreak -and ($parenDepth -eq 0) -and ($braceDepth -eq 0)) {
            $stmt = $BodyText.Substring($start, $i - $start).Trim()
            if (-not [string]::IsNullOrWhiteSpace($stmt)) {
                $statements.Add($stmt)
            }
            if (($ch -eq "`r") -and (($i + 1) -lt $BodyText.Length) -and ($BodyText[$i + 1] -eq "`n")) {
                $i += 1
            }
            $start = $i + 1
        }
    }

    if ($parenDepth -ne 0) {
        Fail-Parse ("unbalanced parentheses in function '{0}' body" -f $FunctionName)
    }
    if ($braceDepth -ne 0) {
        Fail-Parse ("unbalanced block braces in function '{0}' body" -f $FunctionName)
    }

    $tail = $BodyText.Substring($start).Trim()
    if (-not [string]::IsNullOrWhiteSpace($tail)) {
        $statements.Add($tail)
    }

    if ((-not $AllowEmpty) -and ($statements.Count -eq 0)) {
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
    $position = 0

    while ($position -lt $sanitizedProgram.Length) {
        $position = Skip-Stage0Whitespace -Text $sanitizedProgram -StartIndex $position
        if ($position -ge $sanitizedProgram.Length) {
            break
        }

        $headerMatch = [regex]::Match($sanitizedProgram.Substring($position), '^fn\s+([A-Za-z_][A-Za-z0-9_]*)')
        if (-not $headerMatch.Success) {
            Fail-Parse "expected top-level function declaration in stage0 source"
        }

        $functionName = $headerMatch.Groups[1].Value
        Assert-NonKeywordIdentifier -Name $functionName
        if ($definitions.ContainsKey($functionName)) {
            Fail-Parse ("duplicate function '{0}'" -f $functionName)
        }

        $position += $headerMatch.Length
        $position = Skip-Stage0Whitespace -Text $sanitizedProgram -StartIndex $position
        if (($position -ge $sanitizedProgram.Length) -or ($sanitizedProgram[$position] -ne '(')) {
            Fail-Parse ("expected parameter list for function '{0}'" -f $functionName)
        }

        $parameterClose = Get-MatchingDelimiterIndex -Text $sanitizedProgram -StartIndex $position -OpenChar '(' -CloseChar ')' -ContextDescription ("parameter list for function '{0}'" -f $functionName)
        $parameterText = $sanitizedProgram.Substring($position + 1, $parameterClose - $position - 1)
        $position = $parameterClose + 1

        $parameters = @(Parse-Stage0FunctionParameters -FunctionName $functionName -ParameterText $parameterText)

        $position = Skip-Stage0Whitespace -Text $sanitizedProgram -StartIndex $position
        $declaredReturnType = ""
        if ((($position + 1) -lt $sanitizedProgram.Length) -and ($sanitizedProgram.Substring($position, 2) -eq '->')) {
            $position += 2
            $position = Skip-Stage0Whitespace -Text $sanitizedProgram -StartIndex $position
            $returnTypeStart = $position
            while (($position -lt $sanitizedProgram.Length) -and ($sanitizedProgram[$position] -ne '{')) {
                $position += 1
            }

            if ($position -ge $sanitizedProgram.Length) {
                Fail-Parse ("expected body for function '{0}'" -f $functionName)
            }

            $declaredReturnTypeRaw = $sanitizedProgram.Substring($returnTypeStart, $position - $returnTypeStart).Trim()
            if ([string]::IsNullOrWhiteSpace($declaredReturnTypeRaw)) {
                Fail-Parse ("function '{0}' return type annotation is empty" -f $functionName)
            }

            $declaredReturnType = Parse-TypeAnnotation -TypeText $declaredReturnTypeRaw
        }

        $position = Skip-Stage0Whitespace -Text $sanitizedProgram -StartIndex $position
        if (($position -ge $sanitizedProgram.Length) -or ($sanitizedProgram[$position] -ne '{')) {
            Fail-Parse ("expected body for function '{0}'" -f $functionName)
        }

        $bodyClose = Get-MatchingDelimiterIndex -Text $sanitizedProgram -StartIndex $position -OpenChar '{' -CloseChar '}' -ContextDescription ("body for function '{0}'" -f $functionName)
        $bodyText = $sanitizedProgram.Substring($position + 1, $bodyClose - $position - 1)

        $expectedReturnType = Get-ExpectedFunctionReturnType -FunctionName $functionName -DeclaredReturnType $declaredReturnType
        [string[]]$statements = @(Get-Stage0Statements -FunctionName $functionName -BodyText $bodyText)

        $definitions[$functionName] = [pscustomobject]@{
            Name = $functionName
            Parameters = @($parameters)
            DeclaredReturnType = [string]$declaredReturnType
            ExpectedReturnType = [string]$expectedReturnType
            Statements = $statements
        }

        $position = $bodyClose + 1
    }

    if (($definitions.Count -eq 0) -or (-not $definitions.ContainsKey("main"))) {
        Fail-Parse "expected entrypoint pattern fn main() [-> <type>] { ... }"
    }

    return $definitions
}

function Set-ReferenceMetadata {
    param(
        [string]$BindingKey,
        [psobject]$ExprValue,
        [hashtable]$ReferenceTargets
    )

    if (([string]$ExprValue.Type).StartsWith("&")) {
        if (-not ($ExprValue.PSObject.Properties.Name -contains "ReferenceTarget")) {
            Fail-Parse ("reference expression for binding '{0}' is missing reference target metadata" -f (Get-Stage0BindingDisplayName -BindingKey $BindingKey))
        }

        $target = [string]$ExprValue.ReferenceTarget
        if ([string]::IsNullOrWhiteSpace($target)) {
            Fail-Parse ("reference expression for binding '{0}' is missing reference target metadata" -f (Get-Stage0BindingDisplayName -BindingKey $BindingKey))
        }
        $ReferenceTargets[$BindingKey] = $target
        return
    }

    if ($ReferenceTargets.ContainsKey($BindingKey)) {
        $ReferenceTargets.Remove($BindingKey) | Out-Null
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
    foreach ($bindingKey in ($ReferenceTargets.Keys | Sort-Object)) {
        if (-not $Types.ContainsKey($bindingKey)) {
            continue
        }
        if (-not ([string]$Types[$bindingKey]).StartsWith("&")) {
            continue
        }
        if ([string]$ReferenceTargets[$bindingKey] -ne $Target) {
            continue
        }
        if (-not $LifecycleStates.ContainsKey($bindingKey)) {
            continue
        }
        if ([string]$LifecycleStates[$bindingKey] -eq "alive") {
            $aliases.Add([string]$bindingKey)
        }
    }

    return [string[]]$aliases.ToArray()
}

function Remove-Stage0Binding {
    param(
        [string]$BindingKey,
        [hashtable]$Values,
        [hashtable]$Mutable,
        [hashtable]$Types,
        [hashtable]$ResultStates,
        [hashtable]$LifecycleStates,
        [hashtable]$ReferenceTargets
    )

    foreach ($table in @($Values, $Mutable, $Types, $ResultStates, $LifecycleStates, $ReferenceTargets)) {
        if ($table.ContainsKey($BindingKey)) {
            $table.Remove($BindingKey) | Out-Null
        }
    }

    if ($script:Stage0BindingDisplayNames.ContainsKey($BindingKey)) {
        $script:Stage0BindingDisplayNames.Remove($BindingKey) | Out-Null
    }
}

function Remove-BlockScopedBindings {
    param(
        [string[]]$BindingKeys,
        [hashtable]$Values,
        [hashtable]$Mutable,
        [hashtable]$Types,
        [hashtable]$ResultStates,
        [hashtable]$LifecycleStates,
        [hashtable]$ReferenceTargets
    )

    $localNameSet = @{}
    foreach ($bindingKey in $BindingKeys) {
        $localNameSet[$bindingKey] = $true
    }

    foreach ($bindingKey in $BindingKeys) {
        if (-not $Types.ContainsKey($bindingKey)) {
            continue
        }

        $bindingType = [string]$Types[$bindingKey]
        if ($bindingType.StartsWith('&')) {
            continue
        }

        $activeBorrowers = @(Get-LiveReferenceAliasesForTarget -Target $bindingKey -Types $Types -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets)
        foreach ($borrowerKey in $activeBorrowers) {
            if (-not $localNameSet.ContainsKey($borrowerKey)) {
                Fail-Parse ("cannot leave block while identifier '{0}' is borrowed by '{1}'" -f (Get-Stage0BindingDisplayName -BindingKey $bindingKey), (Get-Stage0BindingDisplayName -BindingKey $borrowerKey))
            }
        }
    }

    for ($i = $BindingKeys.Count - 1; $i -ge 0; $i--) {
        Remove-Stage0Binding -BindingKey $BindingKeys[$i] -Values $Values -Mutable $Mutable -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
    }
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
        $bindingKey = Resolve-Stage0BindingKeyOrFail -Name $name -UndefinedMessage "borrow for undefined identifier '$name'"
        $state = [string]$LifecycleStates[$bindingKey]
        if ($state -eq "moved") {
            Fail-Parse "borrow after move for identifier '$name'"
        }
        if ($state -eq "dropped") {
            Fail-Parse "borrow after drop for identifier '$name'"
        }
        if ($state -ne "alive") {
            Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $state, $name)
        }

        $sourceType = [string]$Types[$bindingKey]
        if ($sourceType.StartsWith("&")) {
            Fail-Parse "nested borrow/reference expressions are not available in stage0 bootstrap"
        }

        return [pscustomobject]@{
            Type = "&$sourceType"
            Value = [int]$Values[$bindingKey]
            ResultState = [string]$ResultStates[$bindingKey]
            ReferenceTarget = $bindingKey
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
            $targetKey = [string]$innerValue.ReferenceTarget
            if (-not [string]::IsNullOrWhiteSpace($targetKey)) {
                $targetName = Get-Stage0BindingDisplayName -BindingKey $targetKey
                if (-not $LifecycleStates.ContainsKey($targetKey)) {
                    Fail-Parse ("dereference has unknown reference target '{0}'" -f $targetName)
                }
                $targetState = [string]$LifecycleStates[$targetKey]
                if ($targetState -ne "alive") {
                    Fail-Parse ("dereference of target '{0}' is invalid because target is {1}" -f $targetName, $targetState)
                }

                return [pscustomobject]@{
                    Type = $underlyingType
                    Value = [int]$Values[$targetKey]
                    ResultState = [string]$ResultStates[$targetKey]
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
        $bindingKey = Resolve-Stage0BindingKeyOrFail -Name $name -UndefinedMessage "move for undefined identifier '$name'"
        $state = [string]$LifecycleStates[$bindingKey]
        if ($state -eq "moved") {
            Fail-Parse "double move for identifier '$name'"
        }
        if ($state -eq "dropped") {
            Fail-Parse "move after drop for identifier '$name'"
        }
        if ($state -ne "alive") {
            Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $state, $name)
        }

        $moveType = [string]$Types[$bindingKey]
        if (-not $moveType.StartsWith("&")) {
            $activeBorrowers = @(Get-LiveReferenceAliasesForTarget -Target $bindingKey -Types $Types -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets)
            if ($activeBorrowers.Count -gt 0) {
                Fail-Parse ("cannot move identifier '{0}' while borrowed by '{1}'" -f $name, (Get-Stage0BindingDisplayName -BindingKey $activeBorrowers[0]))
            }
        }

        $moveValue = [int]$Values[$bindingKey]
        $moveResultState = [string]$ResultStates[$bindingKey]
        $moveReferenceTarget = ""
        if ($moveType.StartsWith("&")) {
            $targetKey = Get-Stage0ReferenceTargetKey -BindingKey $bindingKey -ReferenceTargets $ReferenceTargets -LifecycleStates $LifecycleStates
            $targetState = [string]$LifecycleStates[$targetKey]
            if ($targetState -ne "alive") {
                Fail-Parse ("reference target '{0}' is not alive for binding '{1}' (state: {2})" -f (Get-Stage0BindingDisplayName -BindingKey $targetKey), $name, $targetState)
            }

            $moveValue = [int]$Values[$targetKey]
            $moveResultState = [string]$ResultStates[$targetKey]
            $moveReferenceTarget = $targetKey
        }

        $LifecycleStates[$bindingKey] = "moved"
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
    $bindingKey = Resolve-Stage0BindingKeyOrFail -Name $name -UndefinedMessage "undefined identifier '$name'"
    $state = [string]$LifecycleStates[$bindingKey]
    if ($state -eq "moved") {
        Fail-Parse "use after move for identifier '$name'"
    }
    if ($state -eq "dropped") {
        Fail-Parse "use after drop for identifier '$name'"
    }
    if ($state -ne "alive") {
        Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $state, $name)
    }

    $resolvedType = [string]$Types[$bindingKey]
    $resolvedValue = [int]$Values[$bindingKey]
    $resolvedResultState = [string]$ResultStates[$bindingKey]
    $resolvedReferenceTarget = ""
    if ($resolvedType.StartsWith("&")) {
        $targetKey = Get-Stage0ReferenceTargetKey -BindingKey $bindingKey -ReferenceTargets $ReferenceTargets -LifecycleStates $LifecycleStates
        $targetState = [string]$LifecycleStates[$targetKey]
        if ($targetState -ne "alive") {
            Fail-Parse ("reference target '{0}' is not alive for binding '{1}' (state: {2})" -f (Get-Stage0BindingDisplayName -BindingKey $targetKey), $name, $targetState)
        }

        $resolvedValue = [int]$Values[$targetKey]
        $resolvedResultState = [string]$ResultStates[$targetKey]
        $resolvedReferenceTarget = $targetKey
    }

    return [pscustomobject]@{
        Type = $resolvedType
        Value = $resolvedValue
        ResultState = $resolvedResultState
        ReferenceTarget = $resolvedReferenceTarget
    }
}

function Invoke-Stage0Statements {
    param(
        [string]$FunctionName,
        [string]$ExpectedReturnType,
        [string[]]$Statements,
        [hashtable]$Values,
        [hashtable]$Mutable,
        [hashtable]$Types,
        [hashtable]$ResultStates,
        [hashtable]$LifecycleStates,
        [hashtable]$ReferenceTargets,
        [switch]$IsBlockScope
    )

    $haveTerminal = $false
    $functionResult = $null
    $blockBindings = [System.Collections.Generic.List[string]]::new()

    if ($IsBlockScope) {
        Push-Stage0ScopeFrame | Out-Null
    }

    try {
        foreach ($stmt in $Statements) {
            if ($haveTerminal) {
                Fail-Parse 'statements after terminal exit/return are not allowed in stage0'
            }

            if ($stmt.StartsWith('{')) {
                if (($stmt.Length -lt 2) -or (-not $stmt.EndsWith('}'))) {
                    Fail-Parse ("invalid block statement '{0}'" -f $stmt)
                }

                $blockBody = $stmt.Substring(1, $stmt.Length - 2)
                $blockStatements = @(Get-Stage0Statements -FunctionName $FunctionName -BodyText $blockBody -AllowEmpty)
                $blockResult = Invoke-Stage0Statements -FunctionName $FunctionName -ExpectedReturnType $ExpectedReturnType -Statements $blockStatements -Values $Values -Mutable $Mutable -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets -IsBlockScope
                if ($blockResult.HaveTerminal) {
                    $functionResult = $blockResult.Result
                    $haveTerminal = $true
                }
                continue
            }

            if ($stmt -match '^let\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([^?=]+?))?\s*\?=\s*$') {
                Fail-Parse 'unwrap binding requires expression'
            }

            if ($stmt -match '^let\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([^?=]+?))?\s*\?=\s*(.+)$') {
                $name = $Matches[1]
                Assert-NonKeywordIdentifier -Name $name
                $declaredTypeRaw = $Matches[2]
                $expr = $Matches[3]

                $exprValue = Parse-Expr -Expr ('try ' + $expr) -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                $declaredType = if ([string]::IsNullOrWhiteSpace($declaredTypeRaw)) {
                    [string]$exprValue.Type
                }
                else {
                    Parse-TypeAnnotation -TypeText $declaredTypeRaw
                }
                if ([string]$exprValue.Type -ne $declaredType) {
                    Fail-Parse ("type mismatch for binding '{0}': expected {1}, found {2}" -f $name, $declaredType, $exprValue.Type)
                }

                $bindingKey = New-Stage0Binding -Name $name -IsMutable $false -DeclaredType $declaredType -ExprValue $exprValue -Values $Values -Mutable $Mutable -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                if ($IsBlockScope) {
                    $blockBindings.Add($bindingKey) | Out-Null
                }
                continue
            }

            if ($stmt -match '^let\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([^=]+?))?\s*=\s*(.+)$') {
                $name = $Matches[1]
                Assert-NonKeywordIdentifier -Name $name
                $declaredTypeRaw = $Matches[2]
                $expr = $Matches[3]

                $exprValue = Parse-Expr -Expr $expr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                $declaredType = if ([string]::IsNullOrWhiteSpace($declaredTypeRaw)) {
                    [string]$exprValue.Type
                }
                else {
                    Parse-TypeAnnotation -TypeText $declaredTypeRaw
                }
                if ([string]$exprValue.Type -ne $declaredType) {
                    Fail-Parse ("type mismatch for binding '{0}': expected {1}, found {2}" -f $name, $declaredType, $exprValue.Type)
                }

                $bindingKey = New-Stage0Binding -Name $name -IsMutable $false -DeclaredType $declaredType -ExprValue $exprValue -Values $Values -Mutable $Mutable -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                if ($IsBlockScope) {
                    $blockBindings.Add($bindingKey) | Out-Null
                }
                continue
            }

            if ($stmt -match '^var\s+([A-Za-z_][A-Za-z0-9_]*)(?:\s*:\s*([^=]+?))?\s*=\s*(.+)$') {
                $name = $Matches[1]
                Assert-NonKeywordIdentifier -Name $name
                $declaredTypeRaw = $Matches[2]
                $expr = $Matches[3]

                $exprValue = Parse-Expr -Expr $expr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                $declaredType = if ([string]::IsNullOrWhiteSpace($declaredTypeRaw)) {
                    [string]$exprValue.Type
                }
                else {
                    Parse-TypeAnnotation -TypeText $declaredTypeRaw
                }
                if ([string]$exprValue.Type -ne $declaredType) {
                    Fail-Parse ("type mismatch for binding '{0}': expected {1}, found {2}" -f $name, $declaredType, $exprValue.Type)
                }

                $bindingKey = New-Stage0Binding -Name $name -IsMutable $true -DeclaredType $declaredType -ExprValue $exprValue -Values $Values -Mutable $Mutable -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                if ($IsBlockScope) {
                    $blockBindings.Add($bindingKey) | Out-Null
                }
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

                $exprValue = Parse-Expr -Expr ('try ' + $expr) -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                $declaredType = if ([string]::IsNullOrWhiteSpace($declaredTypeRaw)) {
                    [string]$exprValue.Type
                }
                else {
                    Parse-TypeAnnotation -TypeText $declaredTypeRaw
                }
                if ([string]$exprValue.Type -ne $declaredType) {
                    Fail-Parse ("type mismatch for binding '{0}': expected {1}, found {2}" -f $name, $declaredType, $exprValue.Type)
                }

                $bindingKey = New-Stage0Binding -Name $name -IsMutable $true -DeclaredType $declaredType -ExprValue $exprValue -Values $Values -Mutable $Mutable -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                if ($IsBlockScope) {
                    $blockBindings.Add($bindingKey) | Out-Null
                }
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
                $bindingKey = Resolve-Stage0BindingKeyOrFail -Name $name -UndefinedMessage "assignment to undefined identifier '$name'"

                $targetState = [string]$LifecycleStates[$bindingKey]
                if ($targetState -eq 'moved') {
                    Fail-Parse ("compound assignment '+=' requires alive binding '{0}', found moved" -f $name)
                }
                if ($targetState -eq 'dropped') {
                    Fail-Parse ("compound assignment '+=' requires alive binding '{0}', found dropped" -f $name)
                }
                if ($targetState -ne 'alive') {
                    Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $targetState, $name)
                }

                if (-not [bool]$Mutable[$bindingKey]) {
                    Fail-Parse "cannot assign to immutable binding '$name'"
                }

                $exprValue = Parse-Expr -Expr $expr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                $postExprTargetState = [string]$LifecycleStates[$bindingKey]
                if (($postExprTargetState -eq 'dropped') -or ($postExprTargetState -eq 'moved')) {
                    Fail-Parse ("assignment target '{0}' moved or dropped during expression evaluation" -f $name)
                }
                if ($postExprTargetState -ne 'alive') {
                    Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $postExprTargetState, $name)
                }

                $targetType = [string]$Types[$bindingKey]
                if ($targetType -ne 'u8') {
                    Fail-Parse ("compound assignment '+=' expects u8 target in stage0, found {0}" -f $targetType)
                }
                if ([string]$exprValue.Type -ne 'u8') {
                    Fail-Parse ("compound assignment '+=' expects u8 expression in stage0, found {0}" -f $exprValue.Type)
                }

                $activeBorrowers = @(Get-LiveReferenceAliasesForTarget -Target $bindingKey -Types $Types -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets)
                if ($activeBorrowers.Count -gt 0) {
                    Fail-Parse ("cannot assign identifier '{0}' while borrowed by '{1}'" -f $name, (Get-Stage0BindingDisplayName -BindingKey $activeBorrowers[0]))
                }

                $result = [int]$Values[$bindingKey] + [int]$exprValue.Value
                if ($result -gt 255) {
                    Fail-Parse "u8 overflow in '+=' expression"
                }

                $Values[$bindingKey] = $result
                $ResultStates[$bindingKey] = 'none'
                $LifecycleStates[$bindingKey] = 'alive'
                continue
            }

            if ($stmt -match '^([A-Za-z_][A-Za-z0-9_]*)\s*\?=\s*(.+)$') {
                $name = $Matches[1]
                Assert-NonKeywordIdentifier -Name $name
                $expr = $Matches[2]
                $bindingKey = Resolve-Stage0BindingKeyOrFail -Name $name -UndefinedMessage "assignment to undefined identifier '$name'"

                $targetState = [string]$LifecycleStates[$bindingKey]
                if (($targetState -ne 'alive') -and ($targetState -ne 'moved') -and ($targetState -ne 'dropped')) {
                    Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $targetState, $name)
                }
                if (-not [bool]$Mutable[$bindingKey]) {
                    if ($targetState -eq 'moved') {
                        Fail-Parse "cannot reinitialize moved immutable binding '$name'"
                    }
                    if ($targetState -eq 'dropped') {
                        Fail-Parse "cannot reinitialize dropped immutable binding '$name'"
                    }
                    Fail-Parse "cannot assign to immutable binding '$name'"
                }

                $exprValue = Parse-Expr -Expr ('try ' + $expr) -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                $postExprTargetState = [string]$LifecycleStates[$bindingKey]
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

                $targetType = [string]$Types[$bindingKey]
                if (-not $targetType.StartsWith('&')) {
                    $activeBorrowers = @(Get-LiveReferenceAliasesForTarget -Target $bindingKey -Types $Types -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets)
                    if ($activeBorrowers.Count -gt 0) {
                        Fail-Parse ("cannot assign identifier '{0}' while borrowed by '{1}'" -f $name, (Get-Stage0BindingDisplayName -BindingKey $activeBorrowers[0]))
                    }
                }
                if ([string]$exprValue.Type -ne $targetType) {
                    Fail-Parse ("type mismatch for assignment '{0}': expected {1}, found {2}" -f $name, $targetType, $exprValue.Type)
                }

                $Values[$bindingKey] = [int]$exprValue.Value
                $ResultStates[$bindingKey] = [string]$exprValue.ResultState
                $LifecycleStates[$bindingKey] = 'alive'
                Set-ReferenceMetadata -BindingKey $bindingKey -ExprValue $exprValue -ReferenceTargets $ReferenceTargets
                continue
            }

            if ($stmt -match '^([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') {
                $name = $Matches[1]
                Assert-NonKeywordIdentifier -Name $name
                $expr = $Matches[2]
                $bindingKey = Resolve-Stage0BindingKeyOrFail -Name $name -UndefinedMessage "assignment to undefined identifier '$name'"

                $targetState = [string]$LifecycleStates[$bindingKey]
                if (($targetState -ne 'alive') -and ($targetState -ne 'moved') -and ($targetState -ne 'dropped')) {
                    Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $targetState, $name)
                }
                if (-not [bool]$Mutable[$bindingKey]) {
                    if ($targetState -eq 'moved') {
                        Fail-Parse "cannot reinitialize moved immutable binding '$name'"
                    }
                    if ($targetState -eq 'dropped') {
                        Fail-Parse "cannot reinitialize dropped immutable binding '$name'"
                    }
                    Fail-Parse "cannot assign to immutable binding '$name'"
                }

                $exprValue = Parse-Expr -Expr $expr -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                $postExprTargetState = [string]$LifecycleStates[$bindingKey]
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

                $targetType = [string]$Types[$bindingKey]
                if (-not $targetType.StartsWith('&')) {
                    $activeBorrowers = @(Get-LiveReferenceAliasesForTarget -Target $bindingKey -Types $Types -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets)
                    if ($activeBorrowers.Count -gt 0) {
                        Fail-Parse ("cannot assign identifier '{0}' while borrowed by '{1}'" -f $name, (Get-Stage0BindingDisplayName -BindingKey $activeBorrowers[0]))
                    }
                }
                if ([string]$exprValue.Type -ne $targetType) {
                    Fail-Parse ("type mismatch for assignment '{0}': expected {1}, found {2}" -f $name, $targetType, $exprValue.Type)
                }

                $Values[$bindingKey] = [int]$exprValue.Value
                $ResultStates[$bindingKey] = [string]$exprValue.ResultState
                $LifecycleStates[$bindingKey] = 'alive'
                Set-ReferenceMetadata -BindingKey $bindingKey -ExprValue $exprValue -ReferenceTargets $ReferenceTargets
                continue
            }

            if ($stmt -match '^drop\s*\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)$') {
                $name = $Matches[1]
                $bindingKey = Resolve-Stage0BindingKeyOrFail -Name $name -UndefinedMessage "drop for undefined identifier '$name'"
                $state = [string]$LifecycleStates[$bindingKey]
                if ($state -eq 'dropped') {
                    Fail-Parse "double drop for identifier '$name'"
                }
                if ($state -eq 'moved') {
                    Fail-Parse "drop after move for identifier '$name'"
                }
                if ($state -ne 'alive') {
                    Fail-Parse ("invalid binding lifecycle state '{0}' for identifier '{1}'" -f $state, $name)
                }

                $dropType = [string]$Types[$bindingKey]
                if (-not $dropType.StartsWith('&')) {
                    $activeBorrowers = @(Get-LiveReferenceAliasesForTarget -Target $bindingKey -Types $Types -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets)
                    if ($activeBorrowers.Count -gt 0) {
                        Fail-Parse ("cannot drop identifier '{0}' while borrowed by '{1}'" -f $name, (Get-Stage0BindingDisplayName -BindingKey $activeBorrowers[0]))
                    }
                }

                $LifecycleStates[$bindingKey] = 'dropped'
                continue
            }

            if ($stmt -match '^exit\s*\(\s*(.+)\s*\)$') {
                if ($FunctionName -ne 'main') {
                    Fail-Parse ("exit(...) is only allowed in entrypoint function 'main', found in function '{0}'" -f $FunctionName)
                }

                $exprValue = Parse-Expr -Expr $Matches[1] -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                if ([string]$exprValue.Type -ne [string]$ExpectedReturnType) {
                    Fail-Parse ("exit expression type must be {0}, found {1}" -f $ExpectedReturnType, $exprValue.Type)
                }

                $functionResult = [pscustomobject]@{
                    Type = [string]$ExpectedReturnType
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
                $exprValue = Parse-Expr -Expr $Matches[1] -Values $Values -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
                if ([string]$exprValue.Type -ne [string]$ExpectedReturnType) {
                    Fail-Parse ("return expression type must be {0}, found {1}" -f $ExpectedReturnType, $exprValue.Type)
                }

                $functionResult = [pscustomobject]@{
                    Type = [string]$ExpectedReturnType
                    Value = [int]$exprValue.Value
                    ResultState = [string]$exprValue.ResultState
                }
                $haveTerminal = $true
                continue
            }

            Fail-Parse "unsupported statement '$stmt'"
        }
    }
    finally {
        if ($IsBlockScope) {
            Remove-BlockScopedBindings -BindingKeys @($blockBindings.ToArray()) -Values $Values -Mutable $Mutable -Types $Types -ResultStates $ResultStates -LifecycleStates $LifecycleStates -ReferenceTargets $ReferenceTargets
            Pop-Stage0ScopeFrame | Out-Null
        }
    }

    return [pscustomobject]@{
        HaveTerminal = $haveTerminal
        Result = $functionResult
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

    $previousScopeFrames = $script:Stage0ScopeFrames
    $previousDisplayNames = $script:Stage0BindingDisplayNames

    try {
        $script:Stage0ScopeFrames = [System.Collections.Generic.List[hashtable]]::new()
        $script:Stage0BindingDisplayNames = @{}
        Push-Stage0ScopeFrame | Out-Null

        $values = @{}
        $mutable = @{}
        $types = @{}
        $resultStates = @{}
        $lifecycleStates = @{}
        $referenceTargets = @{}

        for ($i = 0; $i -lt $definition.Parameters.Count; $i++) {
            $parameter = $definition.Parameters[$i]
            $argumentValue = $ArgumentValues[$i]
            if ([string]$argumentValue.Type -ne [string]$parameter.Type) {
                Fail-Parse ("type mismatch for parameter '{0}' in function '{1}': expected {2}, found {3}" -f $parameter.Name, $FunctionName, $parameter.Type, $argumentValue.Type)
            }

            $parameterExprValue = [pscustomobject]@{
                Type = [string]$parameter.Type
                Value = [int]$argumentValue.Value
                ResultState = [string]$argumentValue.ResultState
                ReferenceTarget = ''
            }
            New-Stage0Binding -Name $parameter.Name -IsMutable $false -DeclaredType ([string]$parameter.Type) -ExprValue $parameterExprValue -Values $values -Mutable $mutable -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets | Out-Null
        }

        $executionResult = Invoke-Stage0Statements -FunctionName $FunctionName -ExpectedReturnType $definition.ExpectedReturnType -Statements $definition.Statements -Values $values -Mutable $mutable -Types $types -ResultStates $resultStates -LifecycleStates $lifecycleStates -ReferenceTargets $referenceTargets
        if (-not $executionResult.HaveTerminal) {
            if ($FunctionName -eq 'main') {
                Fail-Parse 'missing terminal statement (exit(<expr>) or return <expr>)'
            }
            Fail-Parse ("function '{0}' is missing terminal return" -f $FunctionName)
        }

        return $executionResult.Result
    }
    finally {
        $script:Stage0ScopeFrames = $previousScopeFrames
        $script:Stage0BindingDisplayNames = $previousDisplayNames
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
#     { <stmt>* };
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

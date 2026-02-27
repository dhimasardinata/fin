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

function Parse-Expr {
    param(
        [string]$Expr,
        [hashtable]$Values
    )

    $literal = Parse-U8Literal -Text $Expr
    if ($null -ne $literal) {
        return [int]$literal
    }

    $name = $Expr.Trim()
    if ($name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        Fail-Parse "unsupported expression '$Expr'"
    }
    if (-not $Values.ContainsKey($name)) {
        Fail-Parse "undefined identifier '$name'"
    }

    return [int]$Values[$name]
}

# Stage0 grammar subset:
#   fn main() {
#     (let|var) <ident> = <expr>;
#     <ident> = <expr>;
#     exit(<expr>);
#   }
# <expr> := <u8-literal> | <ident>
# with optional semicolons and line comments (# or //).
$programPattern = '(?s)^\s*fn\s+main\s*\(\s*\)\s*\{\s*(.*?)\s*\}\s*$'
$programMatch = [regex]::Match($raw, $programPattern)
if (-not $programMatch.Success) {
    Fail-Parse "expected entrypoint pattern fn main() { ... }"
}

$body = $programMatch.Groups[1].Value
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
$haveExit = $false
[int]$exitCode = -1

foreach ($stmt in $statements) {
    if ($haveExit) {
        Fail-Parse "statements after exit(...) are not allowed in stage0"
    }

    if ($stmt -match '^let\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') {
        $name = $Matches[1]
        $expr = $Matches[2]
        if ($values.ContainsKey($name)) {
            Fail-Parse "duplicate binding '$name'"
        }
        $values[$name] = Parse-Expr -Expr $expr -Values $values
        $mutable[$name] = $false
        continue
    }

    if ($stmt -match '^var\s+([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.+)$') {
        $name = $Matches[1]
        $expr = $Matches[2]
        if ($values.ContainsKey($name)) {
            Fail-Parse "duplicate binding '$name'"
        }
        $values[$name] = Parse-Expr -Expr $expr -Values $values
        $mutable[$name] = $true
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
        $values[$name] = Parse-Expr -Expr $expr -Values $values
        continue
    }

    if ($stmt -match '^exit\s*\(\s*(.+)\s*\)$') {
        $exitCode = Parse-Expr -Expr $Matches[1] -Values $values
        $haveExit = $true
        continue
    }

    Fail-Parse "unsupported statement '$stmt'"
}

if (-not $haveExit) {
    Fail-Parse "missing exit(<expr>) statement"
}

Write-Output $exitCode

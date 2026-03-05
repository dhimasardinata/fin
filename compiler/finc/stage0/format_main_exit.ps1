param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,
    [switch]$Check,
    [switch]$Stdout
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ($Check -and $Stdout) {
    throw "Cannot combine --check and --stdout modes."
}

$scriptDir = Split-Path -Parent $PSCommandPath
$parser = Join-Path $scriptDir "parse_main_exit.ps1"

function Normalize-Text {
    param([string]$Text)
    return (($Text -replace "`r`n", "`n") -replace "`r", "`n")
}

$sourceText = Get-Content -Path $SourcePath -Raw
$exitCode = [int](& $parser -SourcePath $SourcePath)
$withoutSlashComments = [regex]::Replace($sourceText, '(?m)//.*$', '')
$withoutComments = [regex]::Replace($withoutSlashComments, '(?m)#.*$', '')
$topLevelFunctionCount = ([regex]::Matches($withoutComments, '(?m)^\s*fn\s+[A-Za-z_][A-Za-z0-9_]*\s*\(')).Count

$formatted = if ($topLevelFunctionCount -gt 1) {
    $preserved = Normalize-Text $sourceText
    if (-not $preserved.EndsWith("`n")) {
        $preserved += "`n"
    }
    $preserved
}
else {
    "fn main() {`n  exit($exitCode)`n}`n"
}

if ($Stdout) {
    Write-Output $formatted
    exit 0
}

if ($Check) {
    $current = Get-Content -Path $SourcePath -Raw
    if ((Normalize-Text $current) -ne (Normalize-Text $formatted)) {
        Write-Error "File is not formatted: $SourcePath"
        exit 1
    }
    Write-Host ("formatted_ok={0}" -f (Resolve-Path $SourcePath))
    exit 0
}

Set-Content -Path $SourcePath -Value $formatted -NoNewline
Write-Host ("formatted_written={0}" -f (Resolve-Path $SourcePath))

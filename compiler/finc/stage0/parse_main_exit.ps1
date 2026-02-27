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

# Stage0 grammar subset:
#   fn main() { exit(<u8>) }
# with optional whitespace and optional semicolon.
$pattern = '(?s)^\s*fn\s+main\s*\(\s*\)\s*\{\s*exit\s*\(\s*([0-9]+)\s*\)\s*;?\s*\}\s*$'
$m = [regex]::Match($raw, $pattern)

if (-not $m.Success) {
    Write-Error ("Stage0 parser rejected source. Expected: fn main() {{ exit(<0..255>) }}. File: {0}" -f $SourcePath)
    exit 1
}

$exitCode = [int]$m.Groups[1].Value
if ($exitCode -lt 0 -or $exitCode -gt 255) {
    Write-Error "Stage0 parser requires exit code in range 0..255."
    exit 1
}

Write-Output $exitCode

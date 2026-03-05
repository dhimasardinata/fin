param(
    [string]$Path = "artifacts/fin-pe-exit0.exe",
    [ValidateRange(0, 255)]
    [int]$ExpectedExitCode = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Test-HostIsWindows {
    $isWindowsVar = Get-Variable -Name IsWindows -ErrorAction SilentlyContinue
    if ($null -ne $isWindowsVar) {
        return [bool]$isWindowsVar.Value
    }

    return ($env:OS -eq "Windows_NT")
}

if (-not (Test-Path $Path)) {
    Write-Error "PE binary not found: $Path"
    exit 1
}

if (-not (Test-HostIsWindows)) {
    Write-Host "Windows PE runtime check skipped on non-Windows host."
    $global:LASTEXITCODE = 0
    return
}

$resolvedPath = (Resolve-Path $Path).Path
& $resolvedPath
[int]$actual = $LASTEXITCODE

Write-Host ("program_exit_code={0}" -f $actual)

if ($actual -ne $ExpectedExitCode) {
    Write-Error ("Expected exit code {0}, got {1}" -f $ExpectedExitCode, $actual)
    exit 1
}

Write-Host "Windows PE runtime check passed."
$global:LASTEXITCODE = 0

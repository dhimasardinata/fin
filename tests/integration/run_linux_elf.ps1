param(
    [string]$Path = "artifacts/main",
    [ValidateRange(0, 255)]
    [int]$ExpectedExitCode = 0,
    [string]$ExpectedStdout = ""
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

function Test-HostIsLinux {
    $isLinuxVar = Get-Variable -Name IsLinux -ErrorAction SilentlyContinue
    if ($null -ne $isLinuxVar) {
        return [bool]$isLinuxVar.Value
    }

    try {
        $uname = & uname -s 2>$null
        if ($LASTEXITCODE -eq 0) {
            return ([string]$uname -eq "Linux")
        }
    }
    catch {
    }

    return $false
}

if (-not (Test-Path $Path)) {
    Write-Error "ELF binary not found: $Path"
    exit 1
}

$resolvedPath = (Resolve-Path $Path).Path

function Invoke-LinuxBinary {
    param([string]$LinuxPath)

    & /bin/chmod +x $LinuxPath
    $stdout = & $LinuxPath
    return @{
        ExitCode = [int]$LASTEXITCODE
        Stdout = (($stdout | ForEach-Object { [string]$_ }) -join "`n")
    }
}

function Invoke-WslBinary {
    param([string]$WindowsPath)

    $wsl = Get-Command wsl -ErrorAction SilentlyContinue
    if (-not $wsl) {
        Write-Error "WSL is required to run Linux ELF binaries on Windows."
        exit 1
    }

    $m = [regex]::Match($WindowsPath, '^([A-Za-z]):\\(.*)$')
    if (-not $m.Success) {
        Write-Error "Unsupported Windows path for WSL conversion: $WindowsPath"
        exit 1
    }

    $drive = $m.Groups[1].Value.ToLowerInvariant()
    $rest = $m.Groups[2].Value -replace '\\', '/'
    $linuxPath = "/mnt/$drive/$rest"

    $cmd = "chmod +x `"$linuxPath`"; `"$linuxPath`""
    $stdout = & $wsl.Source bash -lc $cmd
    return @{
        ExitCode = [int]$LASTEXITCODE
        Stdout = (($stdout | ForEach-Object { [string]$_ }) -join "`n")
    }
}

function Normalize-Output {
    param([string]$Text)
    return (($Text -replace "`r`n", "`n") -replace "`r", "`n").TrimEnd("`n")
}

$result = $null
if (Test-HostIsLinux) {
    $result = Invoke-LinuxBinary -LinuxPath $resolvedPath
}
elseif (Test-HostIsWindows) {
    $result = Invoke-WslBinary -WindowsPath $resolvedPath
}
else {
    Write-Error "Unsupported host OS for stage0 run helper."
    exit 1
}

[int]$actual = [int]$result.ExitCode
$actualStdout = Normalize-Output -Text ([string]$result.Stdout)

Write-Host ("program_exit_code={0}" -f $actual)

if ($actual -ne $ExpectedExitCode) {
    Write-Error ("Expected exit code {0}, got {1}" -f $ExpectedExitCode, $actual)
    exit 1
}

if (-not [string]::IsNullOrWhiteSpace($ExpectedStdout)) {
    $expectedStdoutNorm = Normalize-Output -Text $ExpectedStdout
    if ($actualStdout -ne $expectedStdoutNorm) {
        Write-Error ("Expected stdout '{0}', got '{1}'" -f $expectedStdoutNorm, $actualStdout)
        exit 1
    }
}

Write-Host "Linux ELF runtime check passed."
$global:LASTEXITCODE = 0

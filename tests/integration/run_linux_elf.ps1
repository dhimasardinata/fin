param(
    [string]$Path = "artifacts/main",
    [ValidateRange(0, 255)]
    [int]$ExpectedExitCode = 0,
    [string]$ExpectedStdout = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

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
if ($IsLinux) {
    $result = Invoke-LinuxBinary -LinuxPath $resolvedPath
}
elseif ($IsWindows) {
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

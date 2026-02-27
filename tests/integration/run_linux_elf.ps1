param(
    [string]$Path = "artifacts/main",
    [ValidateRange(0, 255)]
    [int]$ExpectedExitCode = 0
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
    & $LinuxPath
    return $LASTEXITCODE
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
    & $wsl.Source bash -lc $cmd
    return $LASTEXITCODE
}

[int]$actual = 0
if ($IsLinux) {
    $actual = Invoke-LinuxBinary -LinuxPath $resolvedPath
}
elseif ($IsWindows) {
    $actual = Invoke-WslBinary -WindowsPath $resolvedPath
}
else {
    Write-Error "Unsupported host OS for stage0 run helper."
    exit 1
}

Write-Host ("program_exit_code={0}" -f $actual)

if ($actual -ne $ExpectedExitCode) {
    Write-Error ("Expected exit code {0}, got {1}" -f $ExpectedExitCode, $actual)
    exit 1
}

Write-Host "Linux ELF runtime check passed."
$global:LASTEXITCODE = 0

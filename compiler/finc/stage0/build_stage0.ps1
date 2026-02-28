param(
    [string]$Source = "src/main.fn",
    [string]$OutFile = "artifacts/main",
    [ValidateSet("x86_64-linux-elf", "x86_64-windows-pe")]
    [string]$Target = "x86_64-linux-elf",
    [ValidateSet("direct", "finobj")]
    [string]$Pipeline = "direct",
    [switch]$Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Remove-Stage0TempPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [int]$MaxAttempts = 8,
        [int]$RetryDelayMs = 150,
        [switch]$IgnoreFailure
    )

    if (-not (Test-Path $Path)) {
        return
    }

    if ($MaxAttempts -lt 1) {
        $MaxAttempts = 1
    }

    $lastError = $null
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Remove-Item -Force $Path -ErrorAction Stop
            return
        }
        catch {
            $lastError = $_
            if ($attempt -lt $MaxAttempts) {
                Start-Sleep -Milliseconds $RetryDelayMs
            }
        }
    }

    if ($IgnoreFailure) {
        Write-Warning ("Failed to remove stage0 temp path after {0} attempts: {1}" -f $MaxAttempts, $Path)
        return
    }

    if ($null -ne $lastError) {
        throw $lastError
    }
}

$scriptDir = Split-Path -Parent $PSCommandPath
$repoRoot = Resolve-Path (Join-Path $scriptDir "..\\..\\..")

$sourcePath = if ([System.IO.Path]::IsPathRooted($Source)) { $Source } else { Join-Path $repoRoot $Source }
$outPath = if ([System.IO.Path]::IsPathRooted($OutFile)) { $OutFile } else { Join-Path $repoRoot $OutFile }

if (-not (Test-Path $sourcePath)) {
    throw "Source file not found: $sourcePath"
}

$outDir = Split-Path -Parent $outPath
if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

[int]$exitCode = 0
if ($Pipeline -eq "direct") {
    $exitCode = & (Join-Path $scriptDir "parse_main_exit.ps1") -SourcePath $sourcePath

    if ($Target -eq "x86_64-linux-elf") {
        & (Join-Path $scriptDir "emit_elf_exit0.ps1") -OutFile $outPath -ExitCode $exitCode
        if ($Verify) {
            & (Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1") -Path $outPath -ExpectedExitCode $exitCode
        }
    }
    elseif ($Target -eq "x86_64-windows-pe") {
        & (Join-Path $scriptDir "emit_pe_exit0.ps1") -OutFile $outPath -ExitCode $exitCode
        if ($Verify) {
            & (Join-Path $repoRoot "tests/bootstrap/verify_pe_exit0.ps1") -Path $outPath -ExpectedExitCode $exitCode
        }
    }
    else {
        throw "Unsupported target: $Target"
    }
}
else {
    $writeFinobj = Join-Path $repoRoot "compiler/finobj/stage0/write_finobj_exit.ps1"
    $readFinobj = Join-Path $repoRoot "compiler/finobj/stage0/read_finobj_exit.ps1"
    $linkFinobj = Join-Path $repoRoot "compiler/finld/stage0/link_finobj_to_elf.ps1"
    $tmpDir = Join-Path $repoRoot "artifacts/tmp/build-stage0"
    if (-not (Test-Path $tmpDir)) {
        New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null
    }

    $outName = [System.IO.Path]::GetFileName($outPath)
    if ([string]::IsNullOrWhiteSpace($outName)) {
        throw "Unable to derive output file name from: $outPath"
    }
    $objPath = Join-Path $tmpDir ("{0}.finobj" -f $outName)
    if (Test-Path $objPath) {
        Remove-Stage0TempPath -Path $objPath
    }

    try {
        & $writeFinobj -SourcePath $sourcePath -OutFile $objPath -Target $Target
        $exitCode = [int](& $readFinobj -ObjectPath $objPath -ExpectedTarget $Target)
        if ($Verify) {
            & $linkFinobj -ObjectPath $objPath -OutFile $outPath -Target $Target -Verify
        }
        else {
            & $linkFinobj -ObjectPath $objPath -OutFile $outPath -Target $Target
        }
    }
    finally {
        Remove-Stage0TempPath -Path $objPath -IgnoreFailure
    }
}

Write-Host ("built_source={0}" -f (Resolve-Path $sourcePath))
Write-Host ("built_output={0}" -f (Resolve-Path $outPath))
Write-Host ("program_exit_code={0}" -f $exitCode)

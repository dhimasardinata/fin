param(
    [string]$SourcePath = "src/main.fn",
    [string]$OutFile = "artifacts/main.finobj"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..\\..")
$parser = Join-Path $repoRoot "compiler/finc/stage0/parse_main_exit.ps1"

function Normalize-Text {
    param([string]$Text)
    return (($Text -replace "`r`n", "`n") -replace "`r", "`n")
}

function Get-TextSha256 {
    param([string]$Text)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.UTF8Encoding]::new($false).GetBytes($Text)
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-RelativePathNormalized {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    $baseDir = [System.IO.Path]::GetFullPath($BasePath)
    $full = [System.IO.Path]::GetFullPath($FullPath)
    Push-Location -Path $baseDir
    try {
        $relative = Resolve-Path -LiteralPath $full -Relative
    }
    finally {
        Pop-Location
    }

    if ($relative.StartsWith(".\")) {
        $relative = $relative.Substring(2)
    }
    elseif ($relative.StartsWith("./")) {
        $relative = $relative.Substring(2)
    }

    return $relative.Replace("\", "/")
}

$sourceFull = if ([System.IO.Path]::IsPathRooted($SourcePath)) {
    [System.IO.Path]::GetFullPath($SourcePath)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $SourcePath))
}

if (-not (Test-Path $sourceFull)) {
    throw "Source file not found: $sourceFull"
}

$outFull = if ([System.IO.Path]::IsPathRooted($OutFile)) {
    [System.IO.Path]::GetFullPath($OutFile)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutFile))
}

$outDir = Split-Path -Parent $outFull
if ($outDir -and -not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

[int]$exitCode = [int](& $parser -SourcePath $sourceFull)
$rawSource = Get-Content -Path $sourceFull -Raw
$sourceHash = Get-TextSha256 -Text (Normalize-Text -Text $rawSource)
$sourceRel = Get-RelativePathNormalized -BasePath $repoRoot -FullPath $sourceFull

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("finobj_format=finobj-stage0")
$lines.Add("finobj_version=1")
$lines.Add("target=x86_64-linux-elf")
$lines.Add("entry_symbol=main")
$lines.Add(("exit_code={0}" -f $exitCode))
$lines.Add(("source_path={0}" -f $sourceRel))
$lines.Add(("source_sha256={0}" -f $sourceHash))

$content = ($lines.ToArray() -join "`n") + "`n"
Set-Content -Path $outFull -Value $content -NoNewline

$objHash = (Get-FileHash -Path $outFull -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ("finobj_written={0}" -f $outFull)
Write-Host ("exit_code={0}" -f $exitCode)
Write-Host ("finobj_sha256={0}" -f $objHash)

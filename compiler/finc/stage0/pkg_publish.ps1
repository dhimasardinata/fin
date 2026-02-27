param(
    [string]$ManifestPath = "fin.toml",
    [string]$SourceDir = "src",
    [string]$OutDir = "artifacts/publish",
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-Sha256HexFromBytes {
    param([byte[]]$Bytes)

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($Bytes)
        return ([System.BitConverter]::ToString($hash)).Replace("-", "").ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-WorkspaceMetadata {
    param([string]$ManifestRaw)

    $section = ""
    $name = ""
    $version = ""

    foreach ($line in ([regex]::Split($ManifestRaw, "`r?`n"))) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("#")) { continue }

        if ($trimmed -match '^\[([^\]]+)\]\s*$') {
            $section = $Matches[1].Trim()
            continue
        }

        if ($section -ne "workspace") {
            continue
        }

        if ($trimmed -match '^name\s*=\s*"([^"]+)"\s*$') {
            $name = $Matches[1].Trim()
            continue
        }

        if ($trimmed -match '^version\s*=\s*"([^"]+)"\s*$') {
            $version = $Matches[1].Trim()
            continue
        }
    }

    if ([string]::IsNullOrWhiteSpace($name)) {
        throw "Manifest is missing [workspace].name."
    }
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "Manifest is missing [workspace].version."
    }
    if ($name -notmatch '^[A-Za-z][A-Za-z0-9_-]*$') {
        throw "Invalid workspace name '$name'. Use pattern: ^[A-Za-z][A-Za-z0-9_-]*$"
    }
    if ($version -match '"') {
        throw "Invalid workspace version '$version'."
    }

    return @{
        Name = $name
        Version = $version
    }
}

function Get-RelativePathNormalized {
    param(
        [string]$BasePath,
        [string]$FullPath
    )

    $baseDir = ([System.IO.Path]::GetFullPath($BasePath)).TrimEnd("\", "/") + [System.IO.Path]::DirectorySeparatorChar
    $baseUri = [System.Uri]$baseDir
    $fileUri = [System.Uri]([System.IO.Path]::GetFullPath($FullPath))
    $relative = [System.Uri]::UnescapeDataString($baseUri.MakeRelativeUri($fileUri).ToString())
    return $relative.Replace("\", "/")
}

if (-not (Test-Path $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}

$manifestFull = [System.IO.Path]::GetFullPath($ManifestPath)
$projectRoot = Split-Path -Path $manifestFull -Parent

$sourceFull = if ([System.IO.Path]::IsPathRooted($SourceDir)) {
    [System.IO.Path]::GetFullPath($SourceDir)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $projectRoot $SourceDir))
}

$outDirFull = if ([System.IO.Path]::IsPathRooted($OutDir)) {
    [System.IO.Path]::GetFullPath($OutDir)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $projectRoot $OutDir))
}

if (-not (Test-Path $sourceFull)) {
    throw "Source directory not found: $sourceFull"
}

$manifestRaw = Get-Content -Path $manifestFull -Raw
$workspace = Get-WorkspaceMetadata -ManifestRaw $manifestRaw

$files = @{}
$files[(Get-RelativePathNormalized -BasePath $projectRoot -FullPath $manifestFull)] = $manifestFull

$lockPath = Join-Path $projectRoot "fin.lock"
if (Test-Path $lockPath) {
    $lockFull = [System.IO.Path]::GetFullPath($lockPath)
    $files[(Get-RelativePathNormalized -BasePath $projectRoot -FullPath $lockFull)] = $lockFull
}

Get-ChildItem -Path $sourceFull -Recurse -File -Filter "*.fn" | ForEach-Object {
    $full = [System.IO.Path]::GetFullPath($_.FullName)
    $rel = Get-RelativePathNormalized -BasePath $projectRoot -FullPath $full
    $files[$rel] = $full
}

$orderedFiles = $files.Keys | Sort-Object

$lines = [System.Collections.Generic.List[string]]::new()
$lines.Add("FINPKG-1")
$lines.Add(("name={0}" -f $workspace.Name))
$lines.Add(("version={0}" -f $workspace.Version))
$lines.Add(("manifest={0}" -f (Get-RelativePathNormalized -BasePath $projectRoot -FullPath $manifestFull)))
$lines.Add(("file_count={0}" -f $orderedFiles.Count))

foreach ($rel in $orderedFiles) {
    $bytes = [System.IO.File]::ReadAllBytes($files[$rel])
    $hash = Get-Sha256HexFromBytes -Bytes $bytes
    $b64 = [System.Convert]::ToBase64String($bytes)

    $lines.Add(("file={0}" -f $rel))
    $lines.Add(("sha256={0}" -f $hash))
    $lines.Add(("bytes={0}" -f $bytes.Length))
    $lines.Add(("base64={0}" -f $b64))
}

$content = ($lines.ToArray() -join "`n") + "`n"
$utf8 = [System.Text.UTF8Encoding]::new($false)
$contentBytes = $utf8.GetBytes($content)
$artifactHash = Get-Sha256HexFromBytes -Bytes $contentBytes

$safeVersion = [regex]::Replace($workspace.Version, '[^A-Za-z0-9._-]', '_')
$artifactName = "{0}-{1}.fnpkg" -f $workspace.Name, $safeVersion
$artifactPath = Join-Path $outDirFull $artifactName

if ($DryRun) {
    Write-Host "publish_mode=dry-run"
    Write-Host ("package_name={0}" -f $workspace.Name)
    Write-Host ("package_version={0}" -f $workspace.Version)
    Write-Host ("artifact_path={0}" -f $artifactPath)
    Write-Host ("artifact_sha256={0}" -f $artifactHash)
    Write-Host ("file_count={0}" -f $orderedFiles.Count)
    return
}

if (-not (Test-Path $outDirFull)) {
    New-Item -ItemType Directory -Path $outDirFull -Force | Out-Null
}

[System.IO.File]::WriteAllText($artifactPath, $content, $utf8)

Write-Host "publish_mode=write"
Write-Host ("package_name={0}" -f $workspace.Name)
Write-Host ("package_version={0}" -f $workspace.Version)
Write-Host ("artifact_path={0}" -f $artifactPath)
Write-Host ("artifact_sha256={0}" -f $artifactHash)
Write-Host ("file_count={0}" -f $orderedFiles.Count)

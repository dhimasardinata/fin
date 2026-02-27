param(
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [string]$Version = "",
    [string]$ManifestPath = "fin.toml"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $ManifestPath)) {
    throw "Manifest not found: $ManifestPath"
}

function Split-PackageInput {
    param([string]$RawName, [string]$RawVersion)

    $name = $RawName.Trim()
    $version = $RawVersion.Trim()

    if ($name.Contains("@")) {
        $parts = $name.Split("@", 2)
        $name = $parts[0].Trim()
        if ([string]::IsNullOrWhiteSpace($version)) {
            $version = $parts[1].Trim()
        }
    }

    if ([string]::IsNullOrWhiteSpace($version)) {
        $version = "*"
    }

    return @($name, $version)
}

function Validate-DependencyName {
    param([string]$DependencyName)
    if ($DependencyName -notmatch '^[A-Za-z][A-Za-z0-9_-]*$') {
        throw "Invalid package name '$DependencyName'. Use pattern: ^[A-Za-z][A-Za-z0-9_-]*$"
    }
}

function Validate-Version {
    param([string]$DependencyVersion)
    if ([string]::IsNullOrWhiteSpace($DependencyVersion)) {
        throw "Package version must be non-empty."
    }
    if ($DependencyVersion -match '"') {
        throw "Package version may not contain quote characters."
    }
}

function Parse-Dependencies {
    param([string[]]$Lines, [int]$Start, [int]$End)

    $map = @{}
    for ($i = $Start; $i -le $End; $i++) {
        $line = $Lines[$i].Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        if ($line.StartsWith("#")) { continue }
        if ($line -match '^([A-Za-z][A-Za-z0-9_-]*)\s*=\s*"([^"]*)"\s*$') {
            $map[$Matches[1]] = $Matches[2]
        }
    }
    return $map
}

function Write-Lockfile {
    param(
        [string]$LockPath,
        [hashtable]$Dependencies,
        [string]$Newline
    )

    $keys = @($Dependencies.Keys | Sort-Object)
    $out = [System.Collections.Generic.List[string]]::new()
    $out.Add("# Lockfile is machine-managed by fin stage0.")
    $out.Add("version = 1")

    if ($keys.Count -eq 0) {
        $out.Add("packages = []")
    }
    else {
        $out.Add("packages = [")
        for ($i = 0; $i -lt $keys.Count; $i++) {
            $k = $keys[$i]
            $v = $Dependencies[$k]
            $line = "  { name = `"$k`", version = `"$v`" }"
            if ($i -lt ($keys.Count - 1)) {
                $line += ","
            }
            $out.Add($line)
        }
        $out.Add("]")
    }

    $content = ($out.ToArray() -join $Newline) + $Newline
    Set-Content -Path $LockPath -Value $content -NoNewline
}

$split = Split-PackageInput -RawName $Name -RawVersion $Version
$depName = $split[0]
$depVersion = $split[1]

Validate-DependencyName -DependencyName $depName
Validate-Version -DependencyVersion $depVersion

$manifestFull = [System.IO.Path]::GetFullPath($ManifestPath)
$raw = Get-Content -Path $manifestFull -Raw
$newline = if ($raw -match "`r`n") { "`r`n" } else { "`n" }

$lines = [System.Collections.Generic.List[string]]::new()
foreach ($line in ([regex]::Split($raw, "`r?`n"))) {
    $lines.Add($line)
}

if ($lines.Count -gt 0 -and $lines[$lines.Count - 1] -eq "") {
    $null = $lines.RemoveAt($lines.Count - 1)
}

$depHeader = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i].Trim() -eq "[dependencies]") {
        $depHeader = $i
        break
    }
}

if ($depHeader -eq -1) {
    $deps = @{}
    $deps[$depName] = $depVersion
    $before = @($lines.ToArray())
    $after = @()
}
else {
    $sectionEnd = $lines.Count - 1
    for ($i = $depHeader + 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -match '^\[[^\]]+\]$') {
            $sectionEnd = $i - 1
            break
        }
    }

    $deps = Parse-Dependencies -Lines $lines.ToArray() -Start ($depHeader + 1) -End $sectionEnd
    $before = @()
    if ($depHeader -gt 0) {
        $before = $lines.GetRange(0, $depHeader).ToArray()
    }
    $after = @()
    if ($sectionEnd + 1 -lt $lines.Count) {
        $after = $lines.GetRange($sectionEnd + 1, $lines.Count - ($sectionEnd + 1)).ToArray()
    }
}

$deps[$depName] = $depVersion
$depKeys = $deps.Keys | Sort-Object

$new = [System.Collections.Generic.List[string]]::new()
foreach ($line in $before) { $new.Add($line) }

if ($new.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace($new[$new.Count - 1])) {
    $new.Add("")
}

$new.Add("[dependencies]")
foreach ($k in $depKeys) {
    $new.Add(("{0} = `"{1}`"" -f $k, $deps[$k]))
}

if ($after.Count -gt 0) {
    if (-not [string]::IsNullOrWhiteSpace($new[$new.Count - 1])) {
        $new.Add("")
    }
    foreach ($line in $after) { $new.Add($line) }
}

$newContent = ($new.ToArray() -join $newline) + $newline
Set-Content -Path $manifestFull -Value $newContent -NoNewline

$lockPath = Join-Path (Split-Path -Path $manifestFull -Parent) "fin.lock"
Write-Lockfile -LockPath $lockPath -Dependencies $deps -Newline $newline

Write-Host ("dependency_added={0}" -f $depName)
Write-Host ("dependency_version={0}" -f $depVersion)
Write-Host ("manifest_updated={0}" -f $manifestFull)
Write-Host ("lock_updated={0}" -f $lockPath)

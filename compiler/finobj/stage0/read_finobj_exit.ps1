param(
    [string]$ObjectPath = "artifacts/main.finobj"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$objFull = [System.IO.Path]::GetFullPath($ObjectPath)
if (-not (Test-Path $objFull)) {
    throw "finobj file not found: $objFull"
}

$raw = Get-Content -Path $objFull -Raw
$map = @{}
foreach ($line in ([regex]::Split($raw, "`r?`n"))) {
    $trimmed = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
    if ($trimmed.StartsWith("#")) { continue }
    if ($trimmed -notmatch '^([A-Za-z0-9_.-]+)\s*=\s*(.+)$') {
        throw "Invalid finobj line: $trimmed"
    }
    $map[$Matches[1]] = $Matches[2].Trim()
}

$required = @(
    "finobj_format",
    "finobj_version",
    "target",
    "entry_symbol",
    "exit_code",
    "source_path",
    "source_sha256"
)
foreach ($k in $required) {
    if (-not $map.ContainsKey($k)) {
        throw "Missing finobj key: $k"
    }
}

if ($map["finobj_format"] -ne "finobj-stage0") {
    throw "Unsupported finobj format: $($map["finobj_format"])"
}
if ($map["finobj_version"] -ne "1") {
    throw "Unsupported finobj version: $($map["finobj_version"])"
}
if ($map["entry_symbol"] -ne "main") {
    throw "Unsupported entry_symbol: $($map["entry_symbol"])"
}

[int]$exitCode = 0
if (-not [int]::TryParse($map["exit_code"], [ref]$exitCode)) {
    throw "Invalid exit_code value: $($map["exit_code"])"
}
if ($exitCode -lt 0 -or $exitCode -gt 255) {
    throw "finobj exit_code out of range 0..255: $exitCode"
}

Write-Host ("finobj_read={0}" -f $objFull)
Write-Host ("target={0}" -f $map["target"])
Write-Host ("entry_symbol={0}" -f $map["entry_symbol"])
Write-Output $exitCode

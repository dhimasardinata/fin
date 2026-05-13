param(
    [string]$Root = "."
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$rootFull = if ([System.IO.Path]::IsPathRooted($Root)) {
    [System.IO.Path]::GetFullPath($Root)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Root))
}

if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) {
    throw "Policy root not found: $rootFull"
}

$disallowed = @(
    "clang\+\+",
    "clang",
    "g\+\+",
    "gcc",
    "cc",
    "ld\.lld",
    "lld-link",
    "link\.exe",
    "ld",
    "as",
    "nasm",
    "yasm",
    "ml64",
    "ml"
)

$regex = "(?i)\b(" + ($disallowed -join "|") + ")\b"
$workflowPath = Join-Path $rootFull ".github/workflows"

if (-not (Test-Path -LiteralPath $workflowPath)) {
    Write-Host "No workflow directory found; skipping check."
    exit 0
}

$violations = @()
$files = @(Get-ChildItem -LiteralPath $workflowPath -Recurse -File | Where-Object {
    $_.Extension -eq ".yml" -or $_.Extension -eq ".yaml"
})

foreach ($file in $files) {
    $lines = Get-Content -LiteralPath $file.FullName
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match "fin-ci-allow-external") {
            continue
        }
        if ($line -match $regex) {
            $violations += "{0}:{1}: {2}" -f $file.FullName, ($i + 1), $line.Trim()
        }
    }
}

if ($violations.Count -gt 0) {
    Write-Error "Disallowed external toolchain references found in workflows:`n$($violations -join "`n")"
    exit 1
}

Write-Host "External toolchain policy check passed."

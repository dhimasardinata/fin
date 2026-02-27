param(
    [string]$Root = "."
)

$disallowed = @(
    "clang",
    "clang\+\+",
    "gcc",
    "g\+\+",
    "\bcc\b",
    "\bld\b",
    "ld\.lld",
    "lld-link",
    "link\.exe",
    "\bas\b",
    "nasm",
    "yasm",
    "\bml\b",
    "ml64"
)

$regex = "(?i)\\b(" + (($disallowed -join "|") -replace "\\b", "") + ")\\b"
$workflowPath = Join-Path $Root ".github/workflows"

if (-not (Test-Path $workflowPath)) {
    Write-Host "No workflow directory found; skipping check."
    exit 0
}

$violations = @()
$files = Get-ChildItem -Path $workflowPath -Recurse -File -Include *.yml,*.yaml

foreach ($file in $files) {
    $lines = Get-Content $file.FullName
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

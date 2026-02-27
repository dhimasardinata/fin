param(
    [string]$Manifest = "fin.toml"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $Manifest)) {
    Write-Error "Missing manifest: $Manifest"
    exit 1
}

$allowedTargets = @(
    "x86_64-linux-elf",
    "x86_64-windows-pe"
)

function Parse-ManifestMap {
    param([string]$Path)

    $raw = Get-Content -Path $Path -Raw
    $map = @{}
    $section = ""

    foreach ($line in ([regex]::Split($raw, "`r?`n"))) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed.StartsWith("#")) { continue }

        if ($trimmed -match '^\[([A-Za-z0-9_.-]+)\]\s*$') {
            $section = $Matches[1]
            continue
        }

        if ($trimmed -notmatch '^([A-Za-z0-9_.-]+)\s*=\s*(.+)$') {
            throw "Invalid manifest line: $trimmed"
        }

        $key = if ([string]::IsNullOrWhiteSpace($section)) {
            $Matches[1]
        }
        else {
            "{0}.{1}" -f $section, $Matches[1]
        }

        if ($map.ContainsKey($key)) {
            throw "Duplicate manifest key: $key"
        }
        $map[$key] = $Matches[2].Trim()
    }

    return $map
}

function Get-RequiredValue {
    param(
        [hashtable]$Map,
        [string]$Key
    )

    if (-not $Map.ContainsKey($Key)) {
        throw "Missing required manifest key: $Key"
    }
    return [string]$Map[$Key]
}

function Decode-StringValue {
    param([string]$Value)

    if ($Value -match '^"([^"]*)"$') {
        return $Matches[1]
    }
    return ""
}

try {
    $map = Parse-ManifestMap -Path $Manifest
}
catch {
    Write-Error $_
    exit 1
}

try {
    $independent = (Get-RequiredValue -Map $map -Key "workspace.independent").ToLowerInvariant()
    if ($independent -ne "true") {
        throw "workspace.independent must be true"
    }

    $seedHashRaw = Get-RequiredValue -Map $map -Key "workspace.seed_hash"
    $seedHash = Decode-StringValue -Value $seedHashRaw
    if ([string]::IsNullOrWhiteSpace($seedHash)) {
        throw "workspace.seed_hash must be a quoted string"
    }

    $extPolicy = (Get-RequiredValue -Map $map -Key "policy.external_toolchain_forbidden").ToLowerInvariant()
    if ($extPolicy -ne "true") {
        throw "policy.external_toolchain_forbidden must be true"
    }

    $reproPolicy = (Get-RequiredValue -Map $map -Key "policy.reproducible_build_required").ToLowerInvariant()
    if ($reproPolicy -ne "true") {
        throw "policy.reproducible_build_required must be true"
    }

    $primaryRaw = Get-RequiredValue -Map $map -Key "targets.primary"
    $secondaryRaw = Get-RequiredValue -Map $map -Key "targets.secondary"
    $primary = Decode-StringValue -Value $primaryRaw
    $secondary = Decode-StringValue -Value $secondaryRaw

    if ([string]::IsNullOrWhiteSpace($primary)) {
        throw "targets.primary must be a quoted string"
    }
    if ([string]::IsNullOrWhiteSpace($secondary)) {
        throw "targets.secondary must be a quoted string"
    }
    if ($allowedTargets -notcontains $primary) {
        throw ("targets.primary must be one of: {0}" -f ($allowedTargets -join ", "))
    }
    if ($allowedTargets -notcontains $secondary) {
        throw ("targets.secondary must be one of: {0}" -f ($allowedTargets -join ", "))
    }
    if ($primary -eq $secondary) {
        throw "targets.primary and targets.secondary must differ"
    }
}
catch {
    Write-Error $_
    exit 1
}

Write-Host "Manifest policy check passed."

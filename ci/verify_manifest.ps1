param(
    [string]$Manifest = "fin.toml",
    [switch]$Quiet
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

function Assert-RequiredCanonicalString {
    param(
        [hashtable]$Map,
        [string]$Key
    )

    $raw = Get-RequiredValue -Map $Map -Key $Key
    $decoded = Decode-StringValue -Value $raw
    if ([string]::IsNullOrWhiteSpace($decoded)) {
        throw ("{0} must be a non-empty quoted string" -f $Key)
    }

    return $decoded
}

function Assert-RequiredTrueBoolean {
    param(
        [hashtable]$Map,
        [string]$Key
    )

    $raw = Get-RequiredValue -Map $Map -Key $Key
    if ($raw -cne "true") {
        throw ("{0} must be canonical true" -f $Key)
    }
}

try {
    $map = Parse-ManifestMap -Path $Manifest
}
catch {
    Write-Error $_
    exit 1
}

try {
    $workspaceName = Assert-RequiredCanonicalString -Map $map -Key "workspace.name"
    if ($workspaceName -notmatch '^[A-Za-z][A-Za-z0-9_-]*$') {
        throw "workspace.name must match ^[A-Za-z][A-Za-z0-9_-]*$"
    }

    $workspaceVersion = Assert-RequiredCanonicalString -Map $map -Key "workspace.version"
    if ($workspaceVersion -match '"') {
        throw "workspace.version may not contain quote characters"
    }

    Assert-RequiredTrueBoolean -Map $map -Key "workspace.independent"

    $seedHash = Assert-RequiredCanonicalString -Map $map -Key "workspace.seed_hash"
    if ($seedHash -ne "UNSET" -and $seedHash -notmatch '^[0-9a-f]{64}$') {
        throw "workspace.seed_hash must be UNSET or a lowercase SHA-256 hex digest"
    }

    Assert-RequiredTrueBoolean -Map $map -Key "policy.external_toolchain_forbidden"
    Assert-RequiredTrueBoolean -Map $map -Key "policy.reproducible_build_required"

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

if (-not $Quiet) {
    Write-Host "Manifest policy check passed."
}

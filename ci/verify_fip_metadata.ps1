param(
    [string]$Root = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($Root)) {
    $repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..")
}
else {
    $repoRoot = Resolve-Path $Root
}
$fipDir = Join-Path $repoRoot "fips"
$indexPath = Join-Path $fipDir "INDEX.md"
$labelsPath = Join-Path $repoRoot ".github/labels.json"
$ciPath = Join-Path $repoRoot ".github/workflows/ci.yml"
$doctorPath = Join-Path $repoRoot "cmd/fin/fin.ps1"

$allowedStatuses = @(
    "Draft",
    "Review",
    "Accepted",
    "Scheduled",
    "InProgress",
    "Implemented",
    "Released",
    "Deferred",
    "Rejected"
)

function Fail-FipMetadata {
    param([string]$Message)

    Write-Error $Message
    exit 1
}

function Get-FipMetadataValue {
    param(
        [string]$Text,
        [string]$Key,
        [string]$Path
    )

    $match = [regex]::Match($Text, ("(?m)^-\s+{0}:\s+(.+?)\s*$" -f [regex]::Escape($Key)))
    if (-not $match.Success) {
        Fail-FipMetadata ("{0} missing metadata key: {1}" -f $Path, $Key)
    }

    return $match.Groups[1].Value.Trim().Trim('"')
}

function Assert-FipSection {
    param(
        [string]$Text,
        [string]$Section,
        [string]$Path
    )

    if ($Text -notmatch ("(?m)^##\s+{0}\s*$" -f [regex]::Escape($Section))) {
        Fail-FipMetadata ("{0} missing section: {1}" -f $Path, $Section)
    }
}

function Get-FipListMetadata {
    param(
        [string]$Text,
        [string]$Key,
        [string]$Path
    )

    $lines = [regex]::Split($Text, "`r?`n")
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $lineMatch = [regex]::Match($lines[$i], ("^-\s+{0}:\s*(.*?)\s*$" -f [regex]::Escape($Key)))
        if (-not $lineMatch.Success) {
            continue
        }

        $inline = $lineMatch.Groups[1].Value.Trim()
        if ($inline -eq "[]") {
            return @()
        }

        if (-not [string]::IsNullOrWhiteSpace($inline)) {
            try {
                $decoded = $inline | ConvertFrom-Json -ErrorAction Stop
            }
            catch {
                Fail-FipMetadata ("{0} invalid {1} list metadata: {2}" -f $Path, $Key, $inline)
            }

            if ($null -eq $decoded) {
                return @()
            }
            return @($decoded | ForEach-Object { [string]$_ })
        }

        $items = [System.Collections.Generic.List[string]]::new()
        for ($j = $i + 1; $j -lt $lines.Count; $j++) {
            if ($lines[$j] -match '^-\s+') {
                break
            }

            $itemMatch = [regex]::Match($lines[$j], '^\s{2}-\s+(.+?)\s*$')
            if ($itemMatch.Success) {
                $items.Add($itemMatch.Groups[1].Value.Trim()) | Out-Null
            }
        }

        return $items.ToArray()
    }

    Fail-FipMetadata ("{0} missing metadata key: {1}" -f $Path, $Key)
}

function Assert-RepoRelativePath {
    param(
        [string]$Value,
        [string]$Label,
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        Fail-FipMetadata ("{0} has empty {1}" -f $Path, $Label)
    }

    if ([System.IO.Path]::IsPathRooted($Value) -or $Value -match '(^|[\\/])\.\.([\\/]|$)') {
        Fail-FipMetadata ("{0} {1} must be a relative repo path without parent traversal: {2}" -f $Path, $Label, $Value)
    }
}

$fips = [System.Collections.Generic.List[object]]::new()
$seenIds = @{}

Get-ChildItem -LiteralPath $fipDir -File -Filter "FIP-*.md" |
    Sort-Object Name |
    ForEach-Object {
        $file = $_
        $path = $file.FullName
        $relativePath = ("fips/{0}" -f $file.Name)
        $nameMatch = [regex]::Match($file.Name, '^(FIP-[0-9]{4})-[A-Za-z0-9][A-Za-z0-9-]*\.md$')
        if (-not $nameMatch.Success) {
            Fail-FipMetadata ("invalid FIP filename: {0}" -f $relativePath)
        }

        $fileId = $nameMatch.Groups[1].Value
        $text = Get-Content -LiteralPath $path -Raw
        $titleMatch = [regex]::Match($text, '(?m)^#\s+(FIP-[0-9]{4}):\s+(.+?)\s*$')
        if (-not $titleMatch.Success) {
            Fail-FipMetadata ("{0} missing canonical title header" -f $relativePath)
        }

        $headerId = $titleMatch.Groups[1].Value
        $title = $titleMatch.Groups[2].Value.Trim()
        $id = Get-FipMetadataValue -Text $text -Key "id" -Path $relativePath
        $address = Get-FipMetadataValue -Text $text -Key "address" -Path $relativePath
        $status = Get-FipMetadataValue -Text $text -Key "status" -Path $relativePath
        $targetRelease = Get-FipMetadataValue -Text $text -Key "target_release" -Path $relativePath
        $requires = @(Get-FipListMetadata -Text $text -Key "requires" -Path $relativePath)
        $implementationPaths = @(Get-FipListMetadata -Text $text -Key "implementation" -Path $relativePath)

        if ($id -ne $fileId -or $headerId -ne $fileId) {
            Fail-FipMetadata ("{0} id mismatch: filename={1} header={2} metadata={3}" -f $relativePath, $fileId, $headerId, $id)
        }

        if ($seenIds.ContainsKey($id)) {
            Fail-FipMetadata ("duplicate FIP id: {0}" -f $id)
        }
        $seenIds[$id] = $true

        $expectedAddress = "fin://fip/{0}" -f $id
        if ($address -ne $expectedAddress) {
            Fail-FipMetadata ("{0} address mismatch: expected={1} actual={2}" -f $relativePath, $expectedAddress, $address)
        }

        if ($allowedStatuses -notcontains $status) {
            Fail-FipMetadata ("{0} invalid status: {1}" -f $relativePath, $status)
        }

        if ($targetRelease -notmatch '^M[0-9]+$') {
            Fail-FipMetadata ("{0} target_release must be M<number>, found: {1}" -f $relativePath, $targetRelease)
        }

        foreach ($requiredFip in $requires) {
            if ($requiredFip -notmatch '^FIP-[0-9]{4}$') {
                Fail-FipMetadata ("{0} has invalid requires entry: {1}" -f $relativePath, $requiredFip)
            }
        }

        foreach ($section in @("Summary", "Motivation", "Design", "Alternatives", "Risks", "Compatibility", "Test Plan")) {
            Assert-FipSection -Text $text -Section $section -Path $relativePath
        }

        if ($text -notmatch '(?m)^-\s+implementation:\s*(\[\])?\s*$') {
            Fail-FipMetadata ("{0} missing implementation metadata" -f $relativePath)
        }

        if ($text -notmatch '(?m)^-\s+acceptance:\s*$') {
            Fail-FipMetadata ("{0} missing acceptance metadata block" -f $relativePath)
        }

        if (($status -in @("Accepted", "Scheduled", "InProgress", "Implemented", "Released")) -and $implementationPaths.Count -eq 0) {
            Fail-FipMetadata ("{0} status {1} requires at least one implementation path" -f $relativePath, $status)
        }

        foreach ($implementationPath in $implementationPaths) {
            Assert-RepoRelativePath -Value $implementationPath -Label "implementation path" -Path $relativePath
            $fullImplementationPath = Join-Path $repoRoot $implementationPath
            if (-not (Test-Path -LiteralPath $fullImplementationPath)) {
                Fail-FipMetadata ("{0} implementation path does not exist: {1}" -f $relativePath, $implementationPath)
            }
        }

        $fips.Add([pscustomobject]@{
            Id = $id
            Title = $title
            Status = $status
            Address = $address
            Requires = $requires
        }) | Out-Null
    }

if ($fips.Count -eq 0) {
    Fail-FipMetadata "no FIP files found"
}

$indexText = Get-Content -LiteralPath $indexPath -Raw
$indexRows = [System.Collections.Generic.List[object]]::new()
foreach ($line in [regex]::Split($indexText, "`r?`n")) {
    $rowMatch = [regex]::Match($line, '^\|\s*(FIP-[0-9]{4})\s*\|\s*(.+?)\s*\|\s*([A-Za-z]+)\s*\|\s*`([^`]+)`\s*\|\s*$')
    if (-not $rowMatch.Success) {
        continue
    }

    $indexRows.Add([pscustomobject]@{
        Id = $rowMatch.Groups[1].Value
        Title = $rowMatch.Groups[2].Value.Trim()
        Status = $rowMatch.Groups[3].Value
        Address = $rowMatch.Groups[4].Value
    }) | Out-Null
}

$expectedIds = @($fips | Sort-Object Id | ForEach-Object { $_.Id })
$actualIds = @($indexRows | ForEach-Object { $_.Id })
if (($expectedIds -join ",") -ne ($actualIds -join ",")) {
    Fail-FipMetadata ("fips/INDEX.md id order mismatch: expected={0} actual={1}" -f ($expectedIds -join ","), ($actualIds -join ","))
}

$fipById = @{}
foreach ($fip in $fips) {
    $fipById[$fip.Id] = $fip
}

foreach ($fip in $fips) {
    foreach ($requiredFip in @($fip.Requires)) {
        if (-not $fipById.ContainsKey($requiredFip)) {
            Fail-FipMetadata ("{0} requires unknown FIP: {1}" -f $fip.Id, $requiredFip)
        }
    }
}

foreach ($row in $indexRows) {
    $fip = $fipById[$row.Id]
    if ($row.Title -ne $fip.Title) {
        Fail-FipMetadata ("fips/INDEX.md title mismatch for {0}: expected={1} actual={2}" -f $row.Id, $fip.Title, $row.Title)
    }
    if ($row.Status -ne $fip.Status) {
        Fail-FipMetadata ("fips/INDEX.md status mismatch for {0}: expected={1} actual={2}" -f $row.Id, $fip.Status, $row.Status)
    }
    if ($row.Address -ne $fip.Address) {
        Fail-FipMetadata ("fips/INDEX.md address mismatch for {0}: expected={1} actual={2}" -f $row.Id, $fip.Address, $row.Address)
    }
}

$labels = Get-Content -LiteralPath $labelsPath -Raw | ConvertFrom-Json
$labelNames = @{}
foreach ($label in $labels) {
    $labelNames[[string]$label.name] = $true
}

foreach ($status in $allowedStatuses) {
    $labelName = "status/{0}" -f $status.ToLowerInvariant()
    if (-not $labelNames.ContainsKey($labelName)) {
        Fail-FipMetadata ("missing GitHub status label: {0}" -f $labelName)
    }
}

$ciText = Get-Content -LiteralPath $ciPath -Raw
if ($ciText -notmatch [regex]::Escape("./ci/verify_fip_metadata.ps1")) {
    Fail-FipMetadata "CI workflow must run ci/verify_fip_metadata.ps1"
}

$doctorText = Get-Content -LiteralPath $doctorPath -Raw
if ($doctorText -notmatch [regex]::Escape("ci/verify_fip_metadata.ps1")) {
    Fail-FipMetadata "fin doctor must run ci/verify_fip_metadata.ps1"
}

Write-Host "FIP metadata check passed."

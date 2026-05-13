Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$policy = Join-Path $repoRoot "ci/verify_seed_hash.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace

$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "seed-hash-policy-gate-"
$tmpRoot = $tmpState.TmpDir
$seedDir = Join-Path $tmpRoot "seed"
$manifest = Join-Path $seedDir "manifest.toml"
$sums = Join-Path $seedDir "SHA256SUMS"

function Assert-Fails {
    param(
        [scriptblock]$Action,
        [string]$Label
    )

    $failed = $false
    try {
        & $Action | Out-Null
    }
    catch {
        $failed = $true
    }

    if (-not $failed) {
        Write-Error ("Expected seed hash policy failure: {0}" -f $Label)
        exit 1
    }
}

function Write-SeedRepo {
    param(
        [string]$ArtifactPath = "seed/fin-seed.bin",
        [string]$Hash = "UNSET",
        [string]$SumsHash = "",
        [string]$SumsPath = "",
        [string]$Format = "native-binary",
        [switch]$CreateArtifact,
        [string]$ArtifactText = "seed"
    )

    Remove-Item -Recurse -Force (Join-Path $tmpRoot "*") -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $seedDir -Force | Out-Null

    $artifactHash = ""
    if ($CreateArtifact) {
        $artifactFull = Join-Path $tmpRoot $ArtifactPath
        New-Item -ItemType Directory -Path (Split-Path -Parent $artifactFull) -Force | Out-Null
        Set-Content -LiteralPath $artifactFull -NoNewline -Value $ArtifactText
        $artifactHash = (Get-FileHash -Algorithm SHA256 -LiteralPath $artifactFull).Hash.ToLowerInvariant()
    }

    if ($Hash -eq "__ARTIFACT__") {
        $Hash = $artifactHash
    }

    if ([string]::IsNullOrWhiteSpace($SumsHash)) {
        $SumsHash = $Hash
    }
    elseif ($SumsHash -eq "__ARTIFACT__") {
        $SumsHash = $artifactHash
    }

    if ([string]::IsNullOrWhiteSpace($SumsPath)) {
        $SumsPath = $ArtifactPath
    }

    Set-Content -LiteralPath $manifest -Value @"
[id]
name = "fin-seed"
version = "0.0.1"

[artifact]
path = "$ArtifactPath"
sha256 = "$Hash"
format = "$Format"

[policy]
immutable_per_release = true
review_required = true
"@

    Set-Content -LiteralPath $sums -Value @"
# Format: <sha256>  <path>
$SumsHash  $SumsPath
"@
}

try {
    Write-SeedRepo
    & $policy -Manifest $manifest -Sums $sums

    Assert-Fails -Label "RequireSet with UNSET hash" -Action { & $policy -Manifest $manifest -Sums $sums -RequireSet }

    Write-SeedRepo -SumsHash ("a" * 64)
    Assert-Fails -Label "manifest/SHA256SUMS hash mismatch" -Action { & $policy -Manifest $manifest -Sums $sums }

    Write-SeedRepo -Hash "not-a-sha"
    Assert-Fails -Label "invalid manifest hash" -Action { & $policy -Manifest $manifest -Sums $sums }

    Write-SeedRepo -SumsHash "not-a-sha"
    Assert-Fails -Label "invalid SHA256SUMS hash" -Action { & $policy -Manifest $manifest -Sums $sums }

    Write-SeedRepo -ArtifactPath "../fin-seed.bin"
    Assert-Fails -Label "unsafe manifest artifact path" -Action { & $policy -Manifest $manifest -Sums $sums }

    Write-SeedRepo -SumsPath "seed/other.bin"
    Assert-Fails -Label "missing SHA256SUMS row for manifest path" -Action { & $policy -Manifest $manifest -Sums $sums }

    Write-SeedRepo -Format "unknown-format"
    Assert-Fails -Label "unsupported artifact format" -Action { & $policy -Manifest $manifest -Sums $sums }

    Write-SeedRepo -CreateArtifact -Hash "__ARTIFACT__" -SumsHash "__ARTIFACT__"
    & $policy -Manifest $manifest -Sums $sums -RequireSet

    Write-SeedRepo -CreateArtifact -Hash ("0" * 64)
    Assert-Fails -Label "artifact hash mismatch" -Action { & $policy -Manifest $manifest -Sums $sums }

    Write-SeedRepo -CreateArtifact
    Assert-Fails -Label "artifact exists while hash is UNSET" -Action { & $policy -Manifest $manifest -Sums $sums }
}
finally {
    Finalize-TestTmpWorkspace -State $tmpState
}

Write-Host "seed hash policy gate self-check passed."

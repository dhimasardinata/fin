Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$policy = Join-Path $repoRoot "ci/verify_seed_hash.ps1"
$tmpWorkspace = Join-Path $repoRoot "tests/common/test_tmp_workspace.ps1"
. $tmpWorkspace
$tmpState = Initialize-TestTmpWorkspace -RepoRoot $repoRoot -Prefix "seed-hash-policy-gate-smoke-"
$tmpRoot = $tmpState.TmpDir
$manifest = Join-Path $tmpRoot "manifest.toml"
$sums = Join-Path $tmpRoot "SHA256SUMS"
$artifact = Join-Path $tmpRoot "fin-seed.bin"

function Write-SeedMetadata {
    param(
        [string]$Path = $artifact,
        [string]$ManifestHash = "UNSET",
        [string]$SumsHash = $ManifestHash
    )

    Set-Content -Path $manifest -Value @"
[id]
name = "fin-seed"
version = "0.0.1"

[artifact]
path = "$Path"
sha256 = "$ManifestHash"
format = "native-binary"

[policy]
immutable_per_release = true
review_required = true
"@

    Set-Content -Path $sums -Value @"
# test seed sums
$SumsHash  $Path
"@
}

function Assert-Fails {
    param(
        [scriptblock]$Action,
        [string]$Label
    )

    $failed = $false
    try {
        & $Action
    }
    catch {
        $failed = $true
    }

    if (-not $failed) {
        Write-Error ("Expected seed hash policy failure: {0}" -f $Label)
        exit 1
    }
}

Write-SeedMetadata
& $policy -Manifest $manifest -Sums $sums
Assert-Fails -Action { & $policy -Manifest $manifest -Sums $sums -RequireSet | Out-Null } -Label "UNSET with RequireSet"

Write-SeedMetadata -ManifestHash "not-a-sha" -SumsHash "not-a-sha"
Assert-Fails -Action { & $policy -Manifest $manifest -Sums $sums | Out-Null } -Label "invalid hash format"

$hashA = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
$hashB = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
Write-SeedMetadata -ManifestHash $hashA -SumsHash $hashB
Assert-Fails -Action { & $policy -Manifest $manifest -Sums $sums | Out-Null } -Label "manifest and sums mismatch"

Write-SeedMetadata -Path $artifact -ManifestHash $hashA -SumsHash $hashA
Set-Content -Path $sums -Value ("{0}  {1}" -f $hashA, (Join-Path $tmpRoot "other-seed.bin"))
Assert-Fails -Action { & $policy -Manifest $manifest -Sums $sums | Out-Null } -Label "missing sums artifact path"

Set-Content -Path $artifact -Value "seed-byte-stream" -NoNewline
$actualHash = (Get-FileHash -Path $artifact -Algorithm SHA256).Hash.ToLowerInvariant()
Write-SeedMetadata -ManifestHash $actualHash -SumsHash $actualHash
& $policy -Manifest $manifest -Sums $sums -RequireSet

Write-SeedMetadata -ManifestHash $hashA -SumsHash $hashA
Assert-Fails -Action { & $policy -Manifest $manifest -Sums $sums -RequireSet | Out-Null } -Label "artifact hash mismatch"

Finalize-TestTmpWorkspace -State $tmpState

Write-Host "seed hash policy gate self-check passed."

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
$fin = Join-Path $repoRoot "cmd/fin/fin.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$runLinux = Join-Path $repoRoot "tests/integration/run_linux_elf.ps1"
$tmpDir = Join-Path $repoRoot "artifacts/tmp/build-pipeline-smoke"

if (Test-Path $tmpDir) {
    Remove-Item -Recurse -Force $tmpDir
}
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

$source = "tests/conformance/fixtures/main_exit7.fn"
$directOut = Join-Path $tmpDir "main-direct"
$finobjOut = Join-Path $tmpDir "main-finobj"
$runOut = Join-Path $tmpDir "main-run-finobj"

& $fin build --src $source --out $directOut --pipeline direct
& $fin build --src $source --out $finobjOut --pipeline finobj

& $verifyElf -Path $directOut -ExpectedExitCode 7
& $verifyElf -Path $finobjOut -ExpectedExitCode 7
& $runLinux -Path $directOut -ExpectedExitCode 7
& $runLinux -Path $finobjOut -ExpectedExitCode 7

$directHash = (Get-FileHash -Path $directOut -Algorithm SHA256).Hash.ToLowerInvariant()
$finobjHash = (Get-FileHash -Path $finobjOut -Algorithm SHA256).Hash.ToLowerInvariant()
if ($directHash -ne $finobjHash) {
    Write-Error ("build pipeline mismatch: direct={0} finobj={1}" -f $directHash, $finobjHash)
    exit 1
}

& $fin run --src $source --out $runOut --pipeline finobj --expect-exit 7

Write-Host ("pipeline_direct_sha256={0}" -f $directHash)
Write-Host ("pipeline_finobj_sha256={0}" -f $finobjHash)
Write-Host "build pipeline finobj integration check passed."

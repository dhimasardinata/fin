param(
    [Parameter(Position = 0)]
    [string]$Command = "",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..")
if ($null -eq $CommandArgs) {
    $CommandArgs = @()
}

function Invoke-Doctor {
    Write-Host "fin doctor: checking repository policy and bootstrap metadata"
    & (Join-Path $repoRoot "ci/verify_manifest.ps1")
    & (Join-Path $repoRoot "ci/verify_seed_hash.ps1")
    & (Join-Path $repoRoot "ci/forbid_external_toolchain.ps1")
    Write-Host "fin doctor: all checks passed"
}

function Invoke-Init {
    $targetDir = (Get-Location).Path
    $name = ""
    $force = $false

    for ($i = 0; $i -lt $CommandArgs.Count; $i++) {
        if ([string]::IsNullOrWhiteSpace($CommandArgs[$i])) {
            continue
        }
        switch ($CommandArgs[$i]) {
            "--dir" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--dir requires a value" }
                $targetDir = $CommandArgs[++$i]
            }
            "--name" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--name requires a value" }
                $name = $CommandArgs[++$i]
            }
            "--force" {
                $force = $true
            }
            default {
                throw "Unknown init argument: $($CommandArgs[$i])"
            }
        }
    }

    if (-not [System.IO.Path]::IsPathRooted($targetDir)) {
        $targetDir = Join-Path (Get-Location).Path $targetDir
    }
    $targetDir = [System.IO.Path]::GetFullPath($targetDir)

    if ([string]::IsNullOrWhiteSpace($name)) {
        $name = Split-Path -Path $targetDir -Leaf
    }
    if ([string]::IsNullOrWhiteSpace($name)) {
        throw "Unable to infer project name. Provide --name."
    }
    if ($name -notmatch '^[A-Za-z][A-Za-z0-9_-]*$') {
        throw "Invalid project name '$name'. Use pattern: ^[A-Za-z][A-Za-z0-9_-]*$"
    }

    if (-not (Test-Path $targetDir)) {
        New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
    }
    $srcDir = Join-Path $targetDir "src"
    if (-not (Test-Path $srcDir)) {
        New-Item -ItemType Directory -Path $srcDir -Force | Out-Null
    }

    $finToml = @"
[workspace]
name = "$name"
version = "0.1.0-dev"
independent = true
seed_hash = "UNSET"

[targets]
primary = "x86_64-linux-elf"
secondary = "x86_64-windows-pe"

[policy]
external_toolchain_forbidden = true
reproducible_build_required = true
"@

    $finLock = @"
# Lockfile is machine-managed by fin stage0 package commands.

version = 1
packages = []
"@

    $mainFn = @"
fn main() {
  exit(0)
}
"@

    $writes = @(
        @{ Path = (Join-Path $targetDir "fin.toml"); Content = $finToml },
        @{ Path = (Join-Path $targetDir "fin.lock"); Content = $finLock },
        @{ Path = (Join-Path $targetDir "src/main.fn"); Content = $mainFn }
    )

    $existing = @()
    foreach ($item in $writes) {
        if (Test-Path $item.Path) {
            $existing += $item.Path
        }
    }
    if ($existing.Count -gt 0 -and -not $force) {
        throw ("Refusing to overwrite existing files:`n{0}`nUse --force to overwrite." -f ($existing -join "`n"))
    }

    foreach ($item in $writes) {
        Set-Content -Path $item.Path -Value $item.Content
    }

    Write-Host ("initialized_project={0}" -f $name)
    Write-Host ("initialized_dir={0}" -f $targetDir)
}

function Invoke-EmitElfExit0 {
    $outFile = if ($CommandArgs.Count -gt 0 -and $CommandArgs[0]) { $CommandArgs[0] } else { "artifacts/fin-elf-exit0" }
    & (Join-Path $repoRoot "compiler/finc/stage0/emit_elf_exit0.ps1") -OutFile $outFile
    & (Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1") -Path $outFile
}

function Invoke-Build {
    $source = "src/main.fn"
    $outFile = "artifacts/main"
    $pipeline = "direct"
    $verify = $true

    for ($i = 0; $i -lt $CommandArgs.Count; $i++) {
        if ([string]::IsNullOrWhiteSpace($CommandArgs[$i])) {
            continue
        }
        switch ($CommandArgs[$i]) {
            "--src" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--src requires a value" }
                $source = $CommandArgs[++$i]
            }
            "--out" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--out requires a value" }
                $outFile = $CommandArgs[++$i]
            }
            "--pipeline" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--pipeline requires a value: direct|finobj" }
                $pipeline = $CommandArgs[++$i]
                if ($pipeline -ne "direct" -and $pipeline -ne "finobj") {
                    throw "--pipeline must be one of: direct, finobj"
                }
            }
            "--no-verify" {
                $verify = $false
            }
            default {
                throw "Unknown build argument: $($CommandArgs[$i])"
            }
        }
    }

    if ($verify) {
        & (Join-Path $repoRoot "compiler/finc/stage0/build_stage0.ps1") -Source $source -OutFile $outFile -Pipeline $pipeline -Verify
    }
    else {
        & (Join-Path $repoRoot "compiler/finc/stage0/build_stage0.ps1") -Source $source -OutFile $outFile -Pipeline $pipeline
    }
}

function Invoke-Run {
    $source = "src/main.fn"
    $outFile = "artifacts/main"
    $pipeline = "direct"
    $verify = $true
    $build = $true
    $expectProvided = $false
    [int]$expectedExitCode = 0

    for ($i = 0; $i -lt $CommandArgs.Count; $i++) {
        if ([string]::IsNullOrWhiteSpace($CommandArgs[$i])) {
            continue
        }
        switch ($CommandArgs[$i]) {
            "--src" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--src requires a value" }
                $source = $CommandArgs[++$i]
            }
            "--out" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--out requires a value" }
                $outFile = $CommandArgs[++$i]
            }
            "--pipeline" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--pipeline requires a value: direct|finobj" }
                $pipeline = $CommandArgs[++$i]
                if ($pipeline -ne "direct" -and $pipeline -ne "finobj") {
                    throw "--pipeline must be one of: direct, finobj"
                }
            }
            "--no-verify" {
                $verify = $false
            }
            "--no-build" {
                $build = $false
            }
            "--expect-exit" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--expect-exit requires a value in range 0..255" }
                $val = [int]$CommandArgs[++$i]
                if ($val -lt 0 -or $val -gt 255) { throw "--expect-exit must be in range 0..255" }
                $expectedExitCode = $val
                $expectProvided = $true
            }
            default {
                throw "Unknown run argument: $($CommandArgs[$i])"
            }
        }
    }

    if ($build) {
        if ($verify) {
            & (Join-Path $repoRoot "compiler/finc/stage0/build_stage0.ps1") -Source $source -OutFile $outFile -Pipeline $pipeline -Verify
        }
        else {
            & (Join-Path $repoRoot "compiler/finc/stage0/build_stage0.ps1") -Source $source -OutFile $outFile -Pipeline $pipeline
        }
    }

    if (-not $expectProvided) {
        $expectedExitCode = [int](& (Join-Path $repoRoot "compiler/finc/stage0/parse_main_exit.ps1") -SourcePath (Join-Path $repoRoot $source))
    }

    & (Join-Path $repoRoot "tests/integration/run_linux_elf.ps1") -Path $outFile -ExpectedExitCode $expectedExitCode
}

function Invoke-Fmt {
    $source = "src/main.fn"
    $check = $false
    $stdout = $false

    for ($i = 0; $i -lt $CommandArgs.Count; $i++) {
        if ([string]::IsNullOrWhiteSpace($CommandArgs[$i])) {
            continue
        }
        switch ($CommandArgs[$i]) {
            "--src" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--src requires a value" }
                $source = $CommandArgs[++$i]
            }
            "--check" { $check = $true }
            "--stdout" { $stdout = $true }
            default { throw "Unknown fmt argument: $($CommandArgs[$i])" }
        }
    }

    $formatter = Join-Path $repoRoot "compiler/finc/stage0/format_main_exit.ps1"
    if ($check -and $stdout) {
        throw "Cannot combine --check and --stdout."
    }
    if ($check) {
        & $formatter -SourcePath $source -Check
    }
    elseif ($stdout) {
        & $formatter -SourcePath $source -Stdout
    }
    else {
        & $formatter -SourcePath $source
    }
}

function Invoke-Doc {
    $source = "src/main.fn"
    $outFile = ""
    $stdout = $false

    for ($i = 0; $i -lt $CommandArgs.Count; $i++) {
        if ([string]::IsNullOrWhiteSpace($CommandArgs[$i])) {
            continue
        }
        switch ($CommandArgs[$i]) {
            "--src" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--src requires a value" }
                $source = $CommandArgs[++$i]
            }
            "--out" {
                if ($i + 1 -ge $CommandArgs.Count) { throw "--out requires a value" }
                $outFile = $CommandArgs[++$i]
            }
            "--stdout" { $stdout = $true }
            default { throw "Unknown doc argument: $($CommandArgs[$i])" }
        }
    }

    $docGen = Join-Path $repoRoot "compiler/finc/stage0/doc_main_exit.ps1"
    if ($stdout -and -not [string]::IsNullOrWhiteSpace($outFile)) {
        throw "Cannot combine --stdout and --out."
    }
    if ($stdout) {
        & $docGen -SourcePath $source -Stdout
    }
    elseif ([string]::IsNullOrWhiteSpace($outFile)) {
        & $docGen -SourcePath $source
    }
    else {
        & $docGen -SourcePath $source -OutFile $outFile
    }
}

function Invoke-Pkg {
    if ($CommandArgs.Count -lt 1 -or [string]::IsNullOrWhiteSpace($CommandArgs[0])) {
        throw "Missing pkg subcommand. Supported: add, publish"
    }

    $sub = $CommandArgs[0]
    $pkgArgs = @()
    if ($CommandArgs.Count -gt 1) {
        $pkgArgs = $CommandArgs[1..($CommandArgs.Count - 1)]
    }

    switch ($sub) {
        "add" {
            if ($pkgArgs.Count -lt 1 -or [string]::IsNullOrWhiteSpace($pkgArgs[0])) {
                throw "Usage: fin pkg add <name[@version]> [--version <ver>] [--manifest <path>]"
            }

            $name = $pkgArgs[0]
            $version = ""
            $manifest = "fin.toml"

            for ($i = 1; $i -lt $pkgArgs.Count; $i++) {
                if ([string]::IsNullOrWhiteSpace($pkgArgs[$i])) { continue }
                switch ($pkgArgs[$i]) {
                    "--version" {
                        if ($i + 1 -ge $pkgArgs.Count) { throw "--version requires a value" }
                        $version = $pkgArgs[++$i]
                    }
                    "--manifest" {
                        if ($i + 1 -ge $pkgArgs.Count) { throw "--manifest requires a value" }
                        $manifest = $pkgArgs[++$i]
                    }
                    default {
                        throw "Unknown pkg add argument: $($pkgArgs[$i])"
                    }
                }
            }

            & (Join-Path $repoRoot "compiler/finc/stage0/pkg_add.ps1") -Name $name -Version $version -ManifestPath $manifest
            break
        }
        "publish" {
            $manifest = "fin.toml"
            $source = "src"
            $outDir = "artifacts/publish"
            $dryRun = $false

            for ($i = 0; $i -lt $pkgArgs.Count; $i++) {
                if ([string]::IsNullOrWhiteSpace($pkgArgs[$i])) { continue }
                switch ($pkgArgs[$i]) {
                    "--manifest" {
                        if ($i + 1 -ge $pkgArgs.Count) { throw "--manifest requires a value" }
                        $manifest = $pkgArgs[++$i]
                    }
                    "--src" {
                        if ($i + 1 -ge $pkgArgs.Count) { throw "--src requires a value" }
                        $source = $pkgArgs[++$i]
                    }
                    "--out-dir" {
                        if ($i + 1 -ge $pkgArgs.Count) { throw "--out-dir requires a value" }
                        $outDir = $pkgArgs[++$i]
                    }
                    "--dry-run" {
                        $dryRun = $true
                    }
                    default {
                        throw "Unknown pkg publish argument: $($pkgArgs[$i])"
                    }
                }
            }

            $publisher = Join-Path $repoRoot "compiler/finc/stage0/pkg_publish.ps1"
            if ($dryRun) {
                & $publisher -ManifestPath $manifest -SourceDir $source -OutDir $outDir -DryRun
            }
            else {
                & $publisher -ManifestPath $manifest -SourceDir $source -OutDir $outDir
            }
            break
        }
        default {
            throw "Unsupported pkg subcommand '$sub'. Supported: add, publish"
        }
    }
}

function Invoke-Test {
    $quick = $false
    $skipDoctor = $false
    $skipRun = $false

    for ($i = 0; $i -lt $CommandArgs.Count; $i++) {
        if ([string]::IsNullOrWhiteSpace($CommandArgs[$i])) {
            continue
        }
        switch ($CommandArgs[$i]) {
            "--quick" { $quick = $true }
            "--no-doctor" { $skipDoctor = $true }
            "--no-run" { $skipRun = $true }
            default { throw "Unknown test argument: $($CommandArgs[$i])" }
        }
    }

    $suite = Join-Path $repoRoot "tests/run_stage0_suite.ps1"
    if ($quick -and $skipDoctor -and $skipRun) {
        & $suite -Quick -SkipDoctor -SkipRun
    }
    elseif ($quick -and $skipDoctor) {
        & $suite -Quick -SkipDoctor
    }
    elseif ($quick -and $skipRun) {
        & $suite -Quick -SkipRun
    }
    elseif ($skipDoctor -and $skipRun) {
        & $suite -SkipDoctor -SkipRun
    }
    elseif ($quick) {
        & $suite -Quick
    }
    elseif ($skipDoctor) {
        & $suite -SkipDoctor
    }
    elseif ($skipRun) {
        & $suite -SkipRun
    }
    else {
        & $suite
    }
}

function Show-Usage {
    @"
fin bootstrap CLI (PowerShell shim)

Usage:
  ./cmd/fin/fin.ps1 init [--name <project>] [--dir <path>] [--force]
  ./cmd/fin/fin.ps1 doctor
  ./cmd/fin/fin.ps1 emit-elf-exit0 [output-path]
  ./cmd/fin/fin.ps1 build [--src <file>] [--out <file>] [--pipeline <direct|finobj>] [--no-verify]
  ./cmd/fin/fin.ps1 run [--src <file>] [--out <file>] [--pipeline <direct|finobj>] [--no-build] [--expect-exit <0..255>] [--no-verify]
  ./cmd/fin/fin.ps1 fmt [--src <file>] [--check | --stdout]
  ./cmd/fin/fin.ps1 doc [--src <file>] [--out <file> | --stdout]
  ./cmd/fin/fin.ps1 pkg add <name[@version]> [--version <ver>] [--manifest <path>]
  ./cmd/fin/fin.ps1 pkg publish [--manifest <path>] [--src <dir>] [--out-dir <path>] [--dry-run]
  ./cmd/fin/fin.ps1 test [--quick] [--no-doctor] [--no-run]

Planned unified commands (tracked in FIP-0015):
  fin init | build | run | test | fmt | doc | pkg add | pkg publish | doctor
"@ | Write-Host
}

switch ($Command) {
    "init" { Invoke-Init; break }
    "doctor" { Invoke-Doctor; break }
    "emit-elf-exit0" { Invoke-EmitElfExit0; break }
    "build" { Invoke-Build; break }
    "run" { Invoke-Run; break }
    "fmt" { Invoke-Fmt; break }
    "doc" { Invoke-Doc; break }
    "pkg" { Invoke-Pkg; break }
    "test" { Invoke-Test; break }
    "" { Show-Usage; break }
    default {
        Write-Error "Unknown command: $Command"
        Show-Usage
        exit 1
    }
}

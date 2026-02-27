param(
    [string[]]$ObjectPath = @("artifacts/main.finobj"),
    [string]$OutFile = "artifacts/main-linked",
    [ValidateSet("x86_64-linux-elf", "x86_64-windows-pe")]
    [string]$Target = "x86_64-linux-elf",
    [switch]$Verify
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot "..\\..\\..")
$reader = Join-Path $repoRoot "compiler/finobj/stage0/read_finobj_exit.ps1"
$emitElf = Join-Path $repoRoot "compiler/finc/stage0/emit_elf_exit0.ps1"
$emitPe = Join-Path $repoRoot "compiler/finc/stage0/emit_pe_exit0.ps1"
$verifyElf = Join-Path $repoRoot "tests/bootstrap/verify_elf_exit0.ps1"
$verifyPe = Join-Path $repoRoot "tests/bootstrap/verify_pe_exit0.ps1"

if ($null -eq $ObjectPath -or $ObjectPath.Count -eq 0) {
    throw "At least one finobj path is required."
}

$objectPaths = [System.Collections.Generic.List[string]]::new()
foreach ($path in $ObjectPath) {
    if ([string]::IsNullOrWhiteSpace($path)) {
        continue
    }

    $objFull = if ([System.IO.Path]::IsPathRooted($path)) {
        [System.IO.Path]::GetFullPath($path)
    }
    else {
        [System.IO.Path]::GetFullPath((Join-Path $repoRoot $path))
    }

    if (-not (Test-Path $objFull)) {
        throw "finobj file not found: $objFull"
    }

    $objectPaths.Add($objFull)
}
if ($objectPaths.Count -eq 0) {
    throw "At least one non-empty finobj path is required."
}

$outFull = if ([System.IO.Path]::IsPathRooted($OutFile)) {
    [System.IO.Path]::GetFullPath($OutFile)
}
else {
    [System.IO.Path]::GetFullPath((Join-Path $repoRoot $OutFile))
}

$records = [System.Collections.Generic.List[object]]::new()
foreach ($obj in $objectPaths) {
    $records.Add((& $reader -ObjectPath $obj -ExpectedTarget $Target -AsRecord))
}

$entryRecords = @($records | Where-Object { $_.EntrySymbol -eq "main" })
if ($entryRecords.Count -eq 0) {
    throw "Link requires exactly one entry object with entry_symbol=main; found none."
}
if ($entryRecords.Count -gt 1) {
    throw ("Link requires exactly one entry object with entry_symbol=main; found {0}." -f $entryRecords.Count)
}

$entryRecord = $entryRecords[0]
[int]$exitCode = [int]$entryRecord.ExitCode
if ($Target -eq "x86_64-linux-elf") {
    & $emitElf -OutFile $outFull -ExitCode $exitCode
}
elseif ($Target -eq "x86_64-windows-pe") {
    & $emitPe -OutFile $outFull -ExitCode $exitCode
}
else {
    throw "Unsupported target: $Target"
}

if ($Verify) {
    if ($Target -eq "x86_64-linux-elf") {
        & $verifyElf -Path $outFull -ExpectedExitCode $exitCode
    }
    else {
        & $verifyPe -Path $outFull -ExpectedExitCode $exitCode
    }
}

Write-Host ("linked_object={0}" -f $entryRecord.ObjectPath)
Write-Host ("linked_objects_count={0}" -f $records.Count)
Write-Host ("linked_output={0}" -f $outFull)
Write-Host ("linked_target={0}" -f $Target)
Write-Host ("program_exit_code={0}" -f $exitCode)

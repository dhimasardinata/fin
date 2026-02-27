param(
    [string]$Path = "artifacts/fin-pe-exit0.exe",
    [ValidateRange(0, 255)]
    [int]$ExpectedExitCode = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $Path)) {
    Write-Error "PE file not found: $Path"
    exit 1
}

[byte[]]$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Path))
if ($bytes.Length -lt 0x400) {
    Write-Error "PE file too small: $($bytes.Length) bytes"
    exit 1
}

function Read-U16([byte[]]$arr, [int]$off) { return [BitConverter]::ToUInt16($arr, $off) }
function Read-U32([byte[]]$arr, [int]$off) { return [BitConverter]::ToUInt32($arr, $off) }
function Read-U64([byte[]]$arr, [int]$off) { return [BitConverter]::ToUInt64($arr, $off) }

if ($bytes[0] -ne 0x4D -or $bytes[1] -ne 0x5A) {
    Write-Error "Invalid DOS header magic; expected MZ."
    exit 1
}

$eLfanew = Read-U32 $bytes 0x3C
if ($eLfanew -ne 0x80) {
    Write-Error ("Expected e_lfanew=0x80, got 0x{0:X}" -f $eLfanew)
    exit 1
}

$peOff = [int]$eLfanew
if ($bytes[$peOff + 0] -ne 0x50 -or $bytes[$peOff + 1] -ne 0x45 -or $bytes[$peOff + 2] -ne 0x00 -or $bytes[$peOff + 3] -ne 0x00) {
    Write-Error "Invalid PE signature."
    exit 1
}

$machine = Read-U16 $bytes ($peOff + 4)
$sections = Read-U16 $bytes ($peOff + 6)
$optHeaderSize = Read-U16 $bytes ($peOff + 20)
if ($machine -ne 0x8664) { Write-Error ("Expected AMD64 machine 0x8664, got 0x{0:X}" -f $machine); exit 1 }
if ($sections -ne 1) { Write-Error ("Expected NumberOfSections=1, got {0}" -f $sections); exit 1 }
if ($optHeaderSize -ne 0xF0) { Write-Error ("Expected SizeOfOptionalHeader=0xF0, got 0x{0:X}" -f $optHeaderSize); exit 1 }

$optOff = $peOff + 24
$magic = Read-U16 $bytes $optOff
$entryRva = Read-U32 $bytes ($optOff + 16)
$baseOfCode = Read-U32 $bytes ($optOff + 20)
$imageBase = Read-U64 $bytes ($optOff + 24)
$sectionAlignment = Read-U32 $bytes ($optOff + 32)
$fileAlignment = Read-U32 $bytes ($optOff + 36)
$sizeOfImage = Read-U32 $bytes ($optOff + 56)
$sizeOfHeaders = Read-U32 $bytes ($optOff + 60)
$subsystem = Read-U16 $bytes ($optOff + 68)

if ($magic -ne 0x20B) { Write-Error ("Expected PE32+ magic 0x20B, got 0x{0:X}" -f $magic); exit 1 }
if ($entryRva -ne 0x1000) { Write-Error ("Expected entry RVA 0x1000, got 0x{0:X}" -f $entryRva); exit 1 }
if ($baseOfCode -ne 0x1000) { Write-Error ("Expected BaseOfCode 0x1000, got 0x{0:X}" -f $baseOfCode); exit 1 }
if ($imageBase -ne 0x0000000140000000) { Write-Error ("Expected ImageBase 0x140000000, got 0x{0:X}" -f $imageBase); exit 1 }
if ($sectionAlignment -ne 0x1000) { Write-Error ("Expected SectionAlignment 0x1000, got 0x{0:X}" -f $sectionAlignment); exit 1 }
if ($fileAlignment -ne 0x200) { Write-Error ("Expected FileAlignment 0x200, got 0x{0:X}" -f $fileAlignment); exit 1 }
if ($sizeOfImage -ne 0x2000) { Write-Error ("Expected SizeOfImage 0x2000, got 0x{0:X}" -f $sizeOfImage); exit 1 }
if ($sizeOfHeaders -ne 0x200) { Write-Error ("Expected SizeOfHeaders 0x200, got 0x{0:X}" -f $sizeOfHeaders); exit 1 }
if ($subsystem -ne 3) { Write-Error ("Expected Subsystem=3 (CUI), got {0}" -f $subsystem); exit 1 }

$sectionOff = $optOff + $optHeaderSize
$nameBytes = $bytes[$sectionOff..($sectionOff + 7)]
$name = ([System.Text.Encoding]::ASCII.GetString($nameBytes)).Trim([char]0)
if ($name -ne ".text") {
    Write-Error ("Expected first section '.text', got '{0}'." -f $name)
    exit 1
}

$virtualSize = Read-U32 $bytes ($sectionOff + 8)
$virtualAddress = Read-U32 $bytes ($sectionOff + 12)
$rawSize = Read-U32 $bytes ($sectionOff + 16)
$rawPtr = Read-U32 $bytes ($sectionOff + 20)
$chars = Read-U32 $bytes ($sectionOff + 36)

if ($virtualAddress -ne 0x1000) { Write-Error ("Expected .text RVA 0x1000, got 0x{0:X}" -f $virtualAddress); exit 1 }
if ($virtualSize -ne 6) { Write-Error ("Expected .text VirtualSize=6, got {0}" -f $virtualSize); exit 1 }
if ($rawSize -ne 0x200) { Write-Error ("Expected .text RawSize=0x200, got 0x{0:X}" -f $rawSize); exit 1 }
if ($rawPtr -ne 0x200) { Write-Error ("Expected .text RawPtr=0x200, got 0x{0:X}" -f $rawPtr); exit 1 }
if ($chars -ne 0x60000020) { Write-Error ("Expected .text characteristics 0x60000020, got 0x{0:X}" -f $chars); exit 1 }

[byte[]]$expectedCode = @(
    0xB8, [byte]($ExpectedExitCode -band 0xFF), 0x00, 0x00, 0x00,
    0xC3
)
for ($i = 0; $i -lt $expectedCode.Length; $i++) {
    if ($bytes[$rawPtr + $i] -ne $expectedCode[$i]) {
        Write-Error ("Code byte mismatch at +{0}: expected 0x{1:X2}, got 0x{2:X2}" -f $i, $expectedCode[$i], $bytes[$rawPtr + $i])
        exit 1
    }
}

$hash = (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "PE structure check passed."
Write-Host ("size={0} exit_code={1} sha256={2}" -f $bytes.Length, $ExpectedExitCode, $hash)

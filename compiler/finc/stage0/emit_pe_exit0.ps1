param(
    [string]$OutFile = "artifacts/fin-pe-exit0.exe",
    [ValidateRange(0, 255)]
    [int]$ExitCode = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Ensure-Directory {
    param([string]$Path)
    $dir = Split-Path -Path $Path -Parent
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

function Align-Up {
    param(
        [int]$Value,
        [int]$Alignment
    )

    return [int](([math]::Ceiling($Value / [double]$Alignment)) * $Alignment)
}

function New-PeExitBytes {
    param([int]$Code)

    $sectionAlignment = 0x1000
    $fileAlignment = 0x200
    $dosStubSize = 0x80
    $optionalHeaderSize = 0xF0
    $sectionHeaderSize = 40

    [byte[]]$codeBytes = @(
        0xB8, [byte]($Code -band 0xFF), 0x00, 0x00, 0x00, # mov eax, <exit_code>
        0xC3                                            # ret
    )

    $virtualAddress = 0x1000
    $virtualSize = $codeBytes.Length
    $rawSize = Align-Up -Value $virtualSize -Alignment $fileAlignment
    $headersUnaligned = $dosStubSize + 4 + 20 + $optionalHeaderSize + $sectionHeaderSize
    $sizeOfHeaders = Align-Up -Value $headersUnaligned -Alignment $fileAlignment
    $sizeOfImage = Align-Up -Value ($virtualAddress + $virtualSize) -Alignment $sectionAlignment
    $totalSize = $sizeOfHeaders + $rawSize

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)

    # DOS header/stub
    [byte[]]$dos = New-Object byte[] $dosStubSize
    $dos[0] = 0x4D # M
    $dos[1] = 0x5A # Z
    [byte[]]$lfanew = [BitConverter]::GetBytes([UInt32]$dosStubSize)
    [Array]::Copy($lfanew, 0, $dos, 0x3C, 4)
    $bw.Write($dos)

    # NT signature + COFF header
    $bw.Write([byte[]]@(0x50, 0x45, 0x00, 0x00)) # "PE\0\0"
    $bw.Write([UInt16]0x8664)                    # Machine: AMD64
    $bw.Write([UInt16]1)                         # NumberOfSections
    $bw.Write([UInt32]0)                         # TimeDateStamp
    $bw.Write([UInt32]0)                         # PointerToSymbolTable
    $bw.Write([UInt32]0)                         # NumberOfSymbols
    $bw.Write([UInt16]$optionalHeaderSize)       # SizeOfOptionalHeader
    $bw.Write([UInt16]0x0022)                    # Characteristics: Executable + LargeAddressAware

    # Optional header (PE32+)
    $bw.Write([UInt16]0x20B)                     # Magic: PE32+
    $bw.Write([byte]0)                           # MajorLinkerVersion
    $bw.Write([byte]0)                           # MinorLinkerVersion
    $bw.Write([UInt32]$rawSize)                  # SizeOfCode
    $bw.Write([UInt32]0)                         # SizeOfInitializedData
    $bw.Write([UInt32]0)                         # SizeOfUninitializedData
    $bw.Write([UInt32]$virtualAddress)           # AddressOfEntryPoint
    $bw.Write([UInt32]$virtualAddress)           # BaseOfCode
    $bw.Write([UInt64]0x0000000140000000)        # ImageBase
    $bw.Write([UInt32]$sectionAlignment)         # SectionAlignment
    $bw.Write([UInt32]$fileAlignment)            # FileAlignment
    $bw.Write([UInt16]6)                         # MajorOperatingSystemVersion
    $bw.Write([UInt16]0)                         # MinorOperatingSystemVersion
    $bw.Write([UInt16]0)                         # MajorImageVersion
    $bw.Write([UInt16]0)                         # MinorImageVersion
    $bw.Write([UInt16]6)                         # MajorSubsystemVersion
    $bw.Write([UInt16]0)                         # MinorSubsystemVersion
    $bw.Write([UInt32]0)                         # Win32VersionValue
    $bw.Write([UInt32]$sizeOfImage)              # SizeOfImage
    $bw.Write([UInt32]$sizeOfHeaders)            # SizeOfHeaders
    $bw.Write([UInt32]0)                         # CheckSum
    $bw.Write([UInt16]3)                         # Subsystem: Windows CUI
    $bw.Write([UInt16]0)                         # DllCharacteristics
    $bw.Write([UInt64]0x100000)                  # SizeOfStackReserve
    $bw.Write([UInt64]0x1000)                    # SizeOfStackCommit
    $bw.Write([UInt64]0x100000)                  # SizeOfHeapReserve
    $bw.Write([UInt64]0x1000)                    # SizeOfHeapCommit
    $bw.Write([UInt32]0)                         # LoaderFlags
    $bw.Write([UInt32]16)                        # NumberOfRvaAndSizes

    # Data directories (16 x zeroed IMAGE_DATA_DIRECTORY)
    for ($i = 0; $i -lt 16; $i++) {
        $bw.Write([UInt32]0)
        $bw.Write([UInt32]0)
    }

    # Section header: .text
    $name = [System.Text.Encoding]::ASCII.GetBytes(".text")
    [byte[]]$nameBuf = New-Object byte[] 8
    [Array]::Copy($name, 0, $nameBuf, 0, $name.Length)
    $bw.Write($nameBuf)
    $bw.Write([UInt32]$virtualSize)              # VirtualSize
    $bw.Write([UInt32]$virtualAddress)           # VirtualAddress
    $bw.Write([UInt32]$rawSize)                  # SizeOfRawData
    $bw.Write([UInt32]$sizeOfHeaders)            # PointerToRawData
    $bw.Write([UInt32]0)                         # PointerToRelocations
    $bw.Write([UInt32]0)                         # PointerToLinenumbers
    $bw.Write([UInt16]0)                         # NumberOfRelocations
    $bw.Write([UInt16]0)                         # NumberOfLinenumbers
    $bw.Write([UInt32]0x60000020)                # Characteristics: CODE|EXECUTE|READ

    # Header padding up to SizeOfHeaders.
    while ($ms.Position -lt $sizeOfHeaders) {
        $bw.Write([byte]0)
    }

    # Code payload + section padding.
    $bw.Write($codeBytes)
    while (($ms.Position - $sizeOfHeaders) -lt $rawSize) {
        $bw.Write([byte]0)
    }

    $bw.Flush()
    $bytes = $ms.ToArray()
    if ($bytes.Length -ne $totalSize) {
        throw ("Unexpected PE size {0}, expected {1}" -f $bytes.Length, $totalSize)
    }
    return $bytes
}

Ensure-Directory -Path $OutFile
$bytes = New-PeExitBytes -Code $ExitCode
[System.IO.File]::WriteAllBytes($OutFile, $bytes)

$hash = (Get-FileHash -Path $OutFile -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ("Wrote {0} bytes to {1}" -f $bytes.Length, (Resolve-Path $OutFile))
Write-Host ("exit_code={0}" -f $ExitCode)
Write-Host ("sha256={0}" -f $hash)

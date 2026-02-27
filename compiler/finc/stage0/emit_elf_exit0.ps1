param(
    [string]$OutFile = "artifacts/fin-elf-exit0",
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

function New-ExitElfBytes {
    param([int]$Code)

    $baseAddr = [UInt64]0x400000
    $elfHeaderSize = 64
    $programHeaderSize = 56

    # Linux x86_64:
    #   mov eax, 60   ; sys_exit
    #   mov edi, <code>
    #   syscall
    [byte[]]$code = @(
        0xB8, 0x3C, 0x00, 0x00, 0x00,
        0xBF, [byte]($Code -band 0xFF), 0x00, 0x00, 0x00,
        0x0F, 0x05
    )

    $codeOffset = $elfHeaderSize + $programHeaderSize
    $fileSize = $codeOffset + $code.Length
    $entry = $baseAddr + [UInt64]$codeOffset

    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)

    # ELF ident (16 bytes)
    $bw.Write([byte[]]@(0x7F, 0x45, 0x4C, 0x46, 2, 1, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0))

    # ELF64 header (little-endian)
    $bw.Write([UInt16]2)              # e_type: ET_EXEC
    $bw.Write([UInt16]62)             # e_machine: EM_X86_64
    $bw.Write([UInt32]1)              # e_version
    $bw.Write([UInt64]$entry)         # e_entry
    $bw.Write([UInt64]64)             # e_phoff
    $bw.Write([UInt64]0)              # e_shoff
    $bw.Write([UInt32]0)              # e_flags
    $bw.Write([UInt16]64)             # e_ehsize
    $bw.Write([UInt16]56)             # e_phentsize
    $bw.Write([UInt16]1)              # e_phnum
    $bw.Write([UInt16]0)              # e_shentsize
    $bw.Write([UInt16]0)              # e_shnum
    $bw.Write([UInt16]0)              # e_shstrndx

    # Program header (PT_LOAD, RX)
    $bw.Write([UInt32]1)              # p_type: PT_LOAD
    $bw.Write([UInt32]5)              # p_flags: PF_R | PF_X
    $bw.Write([UInt64]0)              # p_offset
    $bw.Write([UInt64]$baseAddr)      # p_vaddr
    $bw.Write([UInt64]$baseAddr)      # p_paddr
    $bw.Write([UInt64]$fileSize)      # p_filesz
    $bw.Write([UInt64]$fileSize)      # p_memsz
    $bw.Write([UInt64]0x1000)         # p_align

    # Code payload
    $bw.Write($code)
    $bw.Flush()
    return $ms.ToArray()
}

Ensure-Directory -Path $OutFile
$bytes = New-ExitElfBytes -Code $ExitCode
[System.IO.File]::WriteAllBytes($OutFile, $bytes)

$hash = (Get-FileHash -Path $OutFile -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ("Wrote {0} bytes to {1}" -f $bytes.Length, (Resolve-Path $OutFile))
Write-Host ("exit_code={0}" -f $ExitCode)
Write-Host ("sha256={0}" -f $hash)

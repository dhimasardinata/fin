param(
    [string]$OutFile = "artifacts/fin-elf-write-exit",
    [string]$Message = "hello from fin stage0",
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

function New-WriteExitElfBytes {
    param(
        [string]$Text,
        [int]$Code
    )

    $baseAddr = [UInt64]0x400000
    $elfHeaderSize = 64
    $programHeaderSize = 56
    $codeOffset = $elfHeaderSize + $programHeaderSize

    $utf8 = [System.Text.UTF8Encoding]::new($false)
    [byte[]]$messageBytes = $utf8.GetBytes($Text)
    [UInt32]$messageLen = [UInt32]$messageBytes.Length

    # Linux x86_64:
    #   mov eax, 1            ; sys_write
    #   mov edi, 1            ; fd=stdout
    #   mov rsi, <msg_addr>   ; message pointer
    #   mov edx, <msg_len>    ; byte length
    #   syscall
    #   mov eax, 60           ; sys_exit
    #   mov edi, <exit_code>
    #   syscall
    $codeBytes = [System.Collections.Generic.List[byte]]::new()
    $codeBytes.AddRange([byte[]]@(0xB8, 0x01, 0x00, 0x00, 0x00))
    $codeBytes.AddRange([byte[]]@(0xBF, 0x01, 0x00, 0x00, 0x00))
    $codeBytes.AddRange([byte[]]@(0x48, 0xBE))

    $msgAddrPatchOffset = $codeBytes.Count
    $codeBytes.AddRange([byte[]](0, 0, 0, 0, 0, 0, 0, 0))

    $codeBytes.AddRange([byte[]]@(0xBA))
    $lenPatchOffset = $codeBytes.Count
    $codeBytes.AddRange([byte[]](0, 0, 0, 0))

    $codeBytes.AddRange([byte[]]@(0x0F, 0x05))
    $codeBytes.AddRange([byte[]]@(0xB8, 0x3C, 0x00, 0x00, 0x00))
    $codeBytes.AddRange([byte[]]@(0xBF, [byte]($Code -band 0xFF), 0x00, 0x00, 0x00))
    $codeBytes.AddRange([byte[]]@(0x0F, 0x05))

    $messageOffset = $codeOffset + $codeBytes.Count
    $messageAddr = $baseAddr + [UInt64]$messageOffset

    [byte[]]$msgAddrLe = [BitConverter]::GetBytes([UInt64]$messageAddr)
    for ($i = 0; $i -lt 8; $i++) {
        $codeBytes[$msgAddrPatchOffset + $i] = $msgAddrLe[$i]
    }

    [byte[]]$lenLe = [BitConverter]::GetBytes($messageLen)
    for ($i = 0; $i -lt 4; $i++) {
        $codeBytes[$lenPatchOffset + $i] = $lenLe[$i]
    }

    $fileSize = $messageOffset + $messageBytes.Length
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

    # Code + data payload
    $bw.Write($codeBytes.ToArray())
    $bw.Write($messageBytes)
    $bw.Flush()
    return $ms.ToArray()
}

Ensure-Directory -Path $OutFile
$bytes = New-WriteExitElfBytes -Text $Message -Code $ExitCode
[System.IO.File]::WriteAllBytes($OutFile, $bytes)

$hash = (Get-FileHash -Path $OutFile -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host ("Wrote {0} bytes to {1}" -f $bytes.Length, (Resolve-Path $OutFile))
Write-Host ("exit_code={0}" -f $ExitCode)
Write-Host ("message_len={0}" -f ([System.Text.UTF8Encoding]::new($false).GetByteCount($Message)))
Write-Host ("sha256={0}" -f $hash)

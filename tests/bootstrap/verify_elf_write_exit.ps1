param(
    [string]$Path = "artifacts/fin-elf-write-exit",
    [string]$ExpectedMessage = "hello from fin stage0",
    [ValidateRange(0, 255)]
    [int]$ExpectedExitCode = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $Path)) {
    Write-Error "ELF file not found: $Path"
    exit 1
}

[byte[]]$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $Path))
if ($bytes.Length -lt 159) {
    Write-Error "ELF write+exit file too small: $($bytes.Length) bytes"
    exit 1
}

function Read-U16([byte[]]$arr, [int]$off) { return [BitConverter]::ToUInt16($arr, $off) }
function Read-U32([byte[]]$arr, [int]$off) { return [BitConverter]::ToUInt32($arr, $off) }
function Read-U64([byte[]]$arr, [int]$off) { return [BitConverter]::ToUInt64($arr, $off) }

if (-not ($bytes[0] -eq 0x7F -and $bytes[1] -eq 0x45 -and $bytes[2] -eq 0x4C -and $bytes[3] -eq 0x46)) {
    Write-Error "Invalid ELF magic"
    exit 1
}
if ($bytes[4] -ne 2) { Write-Error "Expected ELF64 class"; exit 1 }
if ($bytes[5] -ne 1) { Write-Error "Expected little-endian encoding"; exit 1 }

$eType = Read-U16 $bytes 16
$eMachine = Read-U16 $bytes 18
$eEntry = Read-U64 $bytes 24
$ePhoff = Read-U64 $bytes 32
$eEhsize = Read-U16 $bytes 52
$ePhentsize = Read-U16 $bytes 54
$ePhnum = Read-U16 $bytes 56

if ($eType -ne 2) { Write-Error "Expected ET_EXEC (2), got $eType"; exit 1 }
if ($eMachine -ne 62) { Write-Error "Expected EM_X86_64 (62), got $eMachine"; exit 1 }
if ($ePhoff -ne 64) { Write-Error "Expected e_phoff=64, got $ePhoff"; exit 1 }
if ($eEhsize -ne 64) { Write-Error "Expected e_ehsize=64, got $eEhsize"; exit 1 }
if ($ePhentsize -ne 56) { Write-Error "Expected e_phentsize=56, got $ePhentsize"; exit 1 }
if ($ePhnum -ne 1) { Write-Error "Expected e_phnum=1, got $ePhnum"; exit 1 }

$pType = Read-U32 $bytes 64
$pFlags = Read-U32 $bytes 68
$pOffset = Read-U64 $bytes 72
$pVaddr = Read-U64 $bytes 80
$pFilesz = Read-U64 $bytes 96
$pMemsz = Read-U64 $bytes 104
$pAlign = Read-U64 $bytes 112

if ($pType -ne 1) { Write-Error "Expected PT_LOAD (1), got $pType"; exit 1 }
if ($pFlags -ne 5) { Write-Error "Expected RX flags (5), got $pFlags"; exit 1 }
if ($pOffset -ne 0) { Write-Error "Expected p_offset=0, got $pOffset"; exit 1 }
if ($pVaddr -ne 0x400000) { Write-Error ("Expected p_vaddr=0x400000, got 0x{0:X}" -f $pVaddr); exit 1 }
if ($pFilesz -ne [UInt64]$bytes.Length) { Write-Error "Expected p_filesz=$($bytes.Length), got $pFilesz"; exit 1 }
if ($pMemsz -ne [UInt64]$bytes.Length) { Write-Error "Expected p_memsz=$($bytes.Length), got $pMemsz"; exit 1 }
if ($pAlign -ne 0x1000) { Write-Error ("Expected p_align=0x1000, got 0x{0:X}" -f $pAlign); exit 1 }

$baseAddr = [UInt64]0x400000
$codeOffset = 120
$codeLength = 39
$messageOffset = $codeOffset + $codeLength
$expectedEntry = [UInt64]($baseAddr + $codeOffset)
if ($eEntry -ne $expectedEntry) {
    Write-Error ("Expected e_entry=0x{0:X}, got 0x{1:X}" -f $expectedEntry, $eEntry)
    exit 1
}

# Fixed opcode bytes around patches.
[byte[]]$prefix = @(
    0xB8, 0x01, 0x00, 0x00, 0x00,       # mov eax,1
    0xBF, 0x01, 0x00, 0x00, 0x00,       # mov edi,1
    0x48, 0xBE                          # mov rsi, imm64
)
for ($i = 0; $i -lt $prefix.Length; $i++) {
    if ($bytes[$codeOffset + $i] -ne $prefix[$i]) {
        Write-Error ("Prefix opcode mismatch at +{0}" -f $i)
        exit 1
    }
}

$msgAddr = Read-U64 $bytes ($codeOffset + 12)
$expectedMsgAddr = $baseAddr + [UInt64]$messageOffset
if ($msgAddr -ne $expectedMsgAddr) {
    Write-Error ("Expected message address 0x{0:X}, got 0x{1:X}" -f $expectedMsgAddr, $msgAddr)
    exit 1
}

if ($bytes[$codeOffset + 20] -ne 0xBA) { Write-Error "Expected mov edx opcode"; exit 1 }
$msgLen = Read-U32 $bytes ($codeOffset + 21)
$expectedMsgBytes = [System.Text.UTF8Encoding]::new($false).GetBytes($ExpectedMessage)
if ($msgLen -ne [UInt32]$expectedMsgBytes.Length) {
    Write-Error ("Expected message length {0}, got {1}" -f $expectedMsgBytes.Length, $msgLen)
    exit 1
}

if ($bytes[$codeOffset + 25] -ne 0x0F -or $bytes[$codeOffset + 26] -ne 0x05) {
    Write-Error "Expected write syscall opcode"
    exit 1
}
if ($bytes[$codeOffset + 27] -ne 0xB8 -or $bytes[$codeOffset + 28] -ne 0x3C) {
    Write-Error "Expected mov eax,60 opcode"
    exit 1
}
if ($bytes[$codeOffset + 32] -ne 0xBF) {
    Write-Error "Expected mov edi,<exit> opcode"
    exit 1
}
$encodedExit = [int]$bytes[$codeOffset + 33]
if ($encodedExit -ne $ExpectedExitCode) {
    Write-Error ("Expected encoded exit code {0}, got {1}" -f $ExpectedExitCode, $encodedExit)
    exit 1
}
if ($bytes[$codeOffset + 37] -ne 0x0F -or $bytes[$codeOffset + 38] -ne 0x05) {
    Write-Error "Expected exit syscall opcode"
    exit 1
}

for ($i = 0; $i -lt $expectedMsgBytes.Length; $i++) {
    if ($bytes[$messageOffset + $i] -ne $expectedMsgBytes[$i]) {
        Write-Error ("Message byte mismatch at +{0}" -f $i)
        exit 1
    }
}

$hash = (Get-FileHash -Path $Path -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "ELF write+exit structure check passed."
Write-Host ("size={0} exit_code={1} message_len={2} sha256={3}" -f $bytes.Length, $ExpectedExitCode, $expectedMsgBytes.Length, $hash)

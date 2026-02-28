Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-FinobjWrittenPath {
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Lines,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    foreach ($line in $Lines) {
        $text = [string]$line
        if ($text -match '^finobj_written=(.+)$') {
            return $Matches[1].Trim()
        }
    }

    Write-Error ("Expected finobj_written output for {0}." -f $Label)
    exit 1
}

function Invoke-FinCommandCaptureFinobjOutput {
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $lines = & $Action *>&1
    $lines | ForEach-Object { Write-Host $_ }
    $finobjPath = Get-FinobjWrittenPath -Lines @($lines) -Label $Label

    return [pscustomobject]@{
        OutputLines = @($lines)
        FinobjPath = [string]$finobjPath
    }
}

function Assert-FinobjTempArtifactCleaned {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    if (Test-Path $Path) {
        Write-Error ("Expected stage0 finobj temp artifact cleanup after {0}: {1}" -f $Label, $Path)
        exit 1
    }
}

function Assert-FileSha256Equal {
    param(
        [Parameter(Mandatory = $true)]
        [string]$LeftPath,
        [Parameter(Mandatory = $true)]
        [string]$RightPath,
        [Parameter(Mandatory = $true)]
        [string]$Label
    )

    $leftHash = (Get-FileHash -Path $LeftPath -Algorithm SHA256).Hash.ToLowerInvariant()
    $rightHash = (Get-FileHash -Path $RightPath -Algorithm SHA256).Hash.ToLowerInvariant()
    if ($leftHash -ne $rightHash) {
        Write-Error ("{0} mismatch: left={1} right={2}" -f $Label, $leftHash, $rightHash)
        exit 1
    }

    return [pscustomobject]@{
        LeftHash = [string]$leftHash
        RightHash = [string]$rightHash
    }
}

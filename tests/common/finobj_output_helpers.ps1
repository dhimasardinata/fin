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

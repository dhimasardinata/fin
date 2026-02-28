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

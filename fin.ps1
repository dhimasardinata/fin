param(
    [Parameter(Position = 0)]
    [string]$Command = "",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
)

& (Join-Path $PSScriptRoot "cmd/fin/fin.ps1") $Command @CommandArgs
exit $LASTEXITCODE

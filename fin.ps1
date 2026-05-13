param(
    [Parameter(Position = 0)]
    [string]$Command = "",

    [Parameter(Position = 1, ValueFromRemainingArguments = $true)]
    [string[]]$CommandArgs
)

& (Join-Path $PSScriptRoot "cmd/fin/fin.ps1") $Command @CommandArgs
exit $LASTEXITCODE

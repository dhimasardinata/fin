param(
    [Parameter(Position = 0)]
    [string]$Command = "",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Args
)

& (Join-Path $PSScriptRoot "cmd/fin/fin.ps1") $Command @Args
exit $LASTEXITCODE

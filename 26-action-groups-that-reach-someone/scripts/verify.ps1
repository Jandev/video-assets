<#
.SYNOPSIS
    Verifies everything in this demo without deploying anything.
    Delegates to verify.sh so both platforms run identical checks.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$verifySh = Join-Path $PSScriptRoot 'verify.sh'

if (-not (Get-Command bash -ErrorAction SilentlyContinue)) {
    throw "bash is required (it ships with Git for Windows, WSL and every Unix)."
}

& bash $verifySh
exit $LASTEXITCODE

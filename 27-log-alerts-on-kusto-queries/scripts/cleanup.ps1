<#
.SYNOPSIS
    Deletes the demo resource group.
.EXAMPLE
    ./cleanup.ps1 -ResourceGroup rg-contoso-demo-27 -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$ResourceGroup = 'rg-contoso-demo-27',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

if ((az group exists --name $ResourceGroup) -ne 'true') {
    Write-Host "$ResourceGroup does not exist. Nothing to do."
    return
}

if (-not $Force) {
    $answer = Read-Host "Delete $ResourceGroup and everything in it? [y/N]"
    if ($answer -ne 'y') { Write-Host "Aborted."; return }
}

if ($PSCmdlet.ShouldProcess($ResourceGroup, 'Delete resource group')) {
    az group delete --name $ResourceGroup --yes --no-wait
    Write-Host "Deletion started (--no-wait)."
}

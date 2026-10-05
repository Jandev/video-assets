[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param([string]$ResourceGroup = 'rg-demo28-foundry-diagnostics')
$ErrorActionPreference = 'Stop'
if ($PSCmdlet.ShouldProcess($ResourceGroup, 'Delete resource group and every resource in it')) {
    az group delete --name $ResourceGroup --yes --no-wait
    Write-Host "Deletion started for $ResourceGroup."
}

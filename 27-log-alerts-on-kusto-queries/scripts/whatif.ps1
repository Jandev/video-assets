<#
.SYNOPSIS
    Runs a resource-group what-if - shows what deploy.ps1 would change.
.EXAMPLE
    ./whatif.ps1 -ResourceGroup rg-contoso-demo-27 -AlertEmailAddress you@example.com
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-contoso-demo-27',
    [string]$Location = 'westeurope',
    [string]$NameSuffix = '',
    [string]$AlertEmailAddress = 'ops-team@example.com'
)

$ErrorActionPreference = 'Stop'
$infra = Join-Path $PSScriptRoot '..' 'infra'

az group create --name $ResourceGroup --location $Location --output none

az deployment group what-if `
    --resource-group $ResourceGroup `
    --template-file (Join-Path $infra 'main.bicep') `
    --parameters location=$Location nameSuffix=$NameSuffix alertEmailAddress=$AlertEmailAddress

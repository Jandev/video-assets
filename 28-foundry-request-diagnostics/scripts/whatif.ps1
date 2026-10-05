[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-demo28-foundry-diagnostics',
    [string]$Location = 'swedencentral',
    [string]$NameSuffix = 'preview28'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$principalId = az ad signed-in-user show --query id -o tsv
az group create --name $ResourceGroup --location $Location --output none
az deployment group what-if --resource-group $ResourceGroup `
    --template-file (Join-Path $root 'infra/main.bicep') `
    --parameters location=$Location nameSuffix=$NameSuffix principalId=$principalId

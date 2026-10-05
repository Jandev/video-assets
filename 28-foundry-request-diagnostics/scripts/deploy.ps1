<#
.SYNOPSIS
Deploys Foundry, a model, and connected Application Insights for demo 28.
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-demo28-foundry-diagnostics',
    [string]$Location = 'swedencentral',
    [string]$NameSuffix = (-join ((97..102) + (48..57) | Get-Random -Count 6 | ForEach-Object { [char]$_ })),
    [string]$ModelName = 'gpt-4.1-mini',
    [string]$ModelVersion = '2025-04-14',
    [string]$ModelDeployment = 'gpt-4.1-mini',
    [int]$ModelCapacity = 10
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$principalId = az ad signed-in-user show --query id -o tsv
$deploymentName = "foundry-diagnostics-$(Get-Date -Format 'yyyyMMddHHmmss')"

az group create --name $ResourceGroup --location $Location --output none
az deployment group create `
    --resource-group $ResourceGroup `
    --name $deploymentName `
    --template-file (Join-Path $root 'infra/main.bicep') `
    --parameters location=$Location nameSuffix=$NameSuffix principalId=$principalId `
                 modelName=$ModelName modelVersion=$ModelVersion `
                 modelDeploymentName=$ModelDeployment modelCapacity=$ModelCapacity `
    --output none
if ($LASTEXITCODE -ne 0) { throw 'Deployment failed.' }

$endpoint = az deployment group show --resource-group $ResourceGroup --name $deploymentName --query 'properties.outputs.foundryProjectEndpoint.value' -o tsv
$appInsights = az deployment group show --resource-group $ResourceGroup --name $deploymentName --query 'properties.outputs.applicationInsightsName.value' -o tsv
$connectionString = az monitor app-insights component show --resource-group $ResourceGroup --app $appInsights --query connectionString -o tsv

$lines = @(
    "`$env:AZURE_AI_FOUNDRY_ENDPOINT = '$endpoint'",
    "`$env:FOUNDRY_PROJECT_ENDPOINT = '$endpoint'",
    "`$env:AZURE_AI_MODEL_DEPLOYMENT = '$ModelDeployment'",
    "`$env:APPLICATIONINSIGHTS_CONNECTION_STRING = '$connectionString'",
    "`$env:AZURE_RESOURCE_GROUP = '$ResourceGroup'",
    "`$env:APPLICATIONINSIGHTS_NAME = '$appInsights'"
)
$lines | Set-Content (Join-Path $root '.azure-outputs.ps1')
Write-Host "Deployment complete. Configuration written to .azure-outputs.ps1" -ForegroundColor Green

<#
.SYNOPSIS
    Deploys the Log Analytics workspace, Application Insights, action group and
    the four log-alert rules.
.EXAMPLE
    ./deploy.ps1 -AlertEmailAddress you@example.com
    ./deploy.ps1 -AlertEmailAddress you@example.com -NameSuffix ab12
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

Write-Host "Resource group : $ResourceGroup"
Write-Host "Location       : $Location"
Write-Host "Name suffix    : $(if ($NameSuffix) { $NameSuffix } else { '<none>' })"
Write-Host "Alert email    : $AlertEmailAddress"
Write-Host ""

az group create --name $ResourceGroup --location $Location --output none

$deploymentName = "log-alerts-demo-$(Get-Date -Format 'yyyyMMddHHmmss')"

az deployment group create `
    --resource-group $ResourceGroup `
    --name $deploymentName `
    --template-file (Join-Path $infra 'main.bicep') `
    --parameters location=$Location `
                 nameSuffix=$NameSuffix `
                 alertEmailAddress=$AlertEmailAddress `
    --output none

if ($LASTEXITCODE -ne 0) { throw "Deployment failed." }

$conn = az deployment group show --resource-group $ResourceGroup --name $deploymentName `
    --query "properties.outputs.appInsightsConnectionString.value" -o tsv
$ws = az deployment group show --resource-group $ResourceGroup --name $deploymentName `
    --query "properties.outputs.workspaceName.value" -o tsv

Write-Host "Deployment complete." -ForegroundColor Green
Write-Host "  Workspace: $ws"
Write-Host ""
Write-Host "Set the connection string, run the API, then drive failures:" -ForegroundColor Cyan
Write-Host "  `$env:APPLICATIONINSIGHTS_CONNECTION_STRING = '$conn'"
Write-Host "  dotnet run --project src/dotnet/Contoso.Demo.LogAlerts.Api"
Write-Host "  ./scripts/generate-failures.ps1 -Url http://localhost:5027 -Scenario server-errors"
Write-Host "  ./scripts/show-alerts.ps1 -ResourceGroup $ResourceGroup"

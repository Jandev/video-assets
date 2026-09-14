<#
.SYNOPSIS
    Deploys the shared action group, the resource health alerts, the cost budget
    and the workload alerts at subscription scope (creates two resource groups).

.EXAMPLE
    ./deploy.ps1 -AlertEmailAddress you@example.com
    ./deploy.ps1 -AlertEmailAddress you@example.com -NameSuffix ab12
#>
[CmdletBinding()]
param(
    [string]$Location = 'westeurope',
    [string]$NameSuffix = '',
    [string]$AlertEmailAddress = 'widget-oncall@example.com',
    [string]$BudgetStartDate = (Get-Date -Format 'yyyy-MM-01')
)

$ErrorActionPreference = 'Stop'
$infra = Join-Path $PSScriptRoot '..' 'infra'

Write-Host "Location      : $Location"
Write-Host "Name suffix   : $(if ($NameSuffix) { $NameSuffix } else { '<none>' })"
Write-Host "Alert email   : $AlertEmailAddress"
Write-Host "Budget starts : $BudgetStartDate"
Write-Host ""

$deploymentName = "contoso-demo-26-$(Get-Date -Format 'yyyyMMddHHmmss')"

az deployment sub create `
    --name $deploymentName `
    --location $Location `
    --template-file (Join-Path $infra 'main.bicep') `
    --parameters location=$Location `
                 nameSuffix=$NameSuffix `
                 alertEmailAddress=$AlertEmailAddress `
                 budgetStartDate=$BudgetStartDate `
    --output none

if ($LASTEXITCODE -ne 0) { throw "Deployment failed." }

$agName = az deployment sub show --name $deploymentName `
    --query "properties.outputs.actionGroupName.value" -o tsv
$mgmtRg = az deployment sub show --name $deploymentName `
    --query "properties.outputs.managementResourceGroup.value" -o tsv

Write-Host "Deployment complete." -ForegroundColor Green
Write-Host "  Action group     : $agName"
Write-Host "  Management group  : $mgmtRg"
Write-Host ""
Write-Host "Fire a real test notification so the video has something to show:" -ForegroundColor Cyan
Write-Host "  ./scripts/fire-test-alert.ps1 -ResourceGroup $mgmtRg -ActionGroup $agName -AlertEmailAddress $AlertEmailAddress"

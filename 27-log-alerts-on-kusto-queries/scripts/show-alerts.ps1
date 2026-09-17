<#
.SYNOPSIS
    Shows the deployed log-alert rules and any recent fired alerts.
.EXAMPLE
    ./show-alerts.ps1 -ResourceGroup rg-contoso-demo-27
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-contoso-demo-27'
)

$ErrorActionPreference = 'Stop'

Write-Host "`n=== Scheduled query alert rules ================================================" -ForegroundColor Cyan
# `az monitor scheduled-query` is the log-alert (scheduledQueryRules) surface.
# NOTE: `az monitor activity-log alert` is a DIFFERENT thing, not this demo.
az monitor scheduled-query list --resource-group $ResourceGroup `
    --query "[].{Name:name, Severity:severity, Enabled:enabled, Every:evaluationFrequency, Window:windowSize}" `
    -o table

Write-Host "`n=== Fired alerts (last 24h) ====================================================" -ForegroundColor Cyan
$subscription = az account show --query id -o tsv
$url = "https://management.azure.com/subscriptions/$subscription/providers/Microsoft.AlertsManagement/alerts?api-version=2019-05-05-preview&timeRange=1d"
az rest --method get --url $url `
    --query "value[?contains(properties.essentials.targetResourceGroup, '$ResourceGroup')].{Name:name, Severity:properties.essentials.severity, State:properties.essentials.monitorCondition, FiredAt:properties.essentials.startDateTime}" `
    -o table
Write-Host ""

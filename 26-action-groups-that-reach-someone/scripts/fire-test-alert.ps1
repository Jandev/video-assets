<#
.SYNOPSIS
    Fires a REAL test notification through the shared action group, so the video
    has something to show. Uses Azure Monitor's test-notifications API to send an
    actual email / webhook / role notification without waiting for a real alert.

.EXAMPLE
    ./fire-test-alert.ps1 -ResourceGroup rg-contoso-demo-26-management `
        -ActionGroup contoso-demo-26-oncall -AlertEmailAddress you@example.com
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-contoso-demo-26-management',
    [string]$ActionGroup = 'contoso-demo-26-oncall',
    [string]$AlertEmailAddress = 'widget-oncall@example.com',
    [string]$AlertType = 'resourcehealth'
)

$ErrorActionPreference = 'Stop'

$ownerRoleId = '8e3af657-a8ff-443c-a75c-2fe8c4bcb635'        # Azure built-in: Owner
$contributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'  # Azure built-in: Contributor

Write-Host "Firing a test '$AlertType' notification through:"
Write-Host "  Action group : $ActionGroup  (resource group $ResourceGroup)"
Write-Host "  Email lands  : $AlertEmailAddress"
Write-Host "  ARM roles    : Owner + Contributor on the subscription"
Write-Host ""

# Preferred path: the first-class CLI command.
az monitor action-group test-notifications create --help *> $null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Using: az monitor action-group test-notifications create"
    az monitor action-group test-notifications create `
        --resource-group $ResourceGroup `
        --action-group $ActionGroup `
        --alert-type $AlertType `
        --add-action email oncall-distribution $AlertEmailAddress usecommonalertschema `
        --add-action armrole subscription-owners $ownerRoleId usecommonalertschema `
        --add-action armrole subscription-contributors $contributorRoleId usecommonalertschema
    if ($LASTEXITCODE -ne 0) { throw "test-notifications create failed." }
    Write-Host ""
    Write-Host "Notification dispatched. Give email a minute or two to arrive." -ForegroundColor Green
    return
}

# Fallback: call the ARM createNotifications endpoint directly.
Write-Host "CLI command unavailable - falling back to the ARM REST endpoint."
$subId = az account show --query id -o tsv
$apiVersion = '2023-01-01'
$url = "https://management.azure.com/subscriptions/$subId/providers/Microsoft.Insights/createNotifications?api-version=$apiVersion"

$body = @{
    alertType      = $AlertType
    emailReceivers = @(
        @{ name = 'oncall-distribution'; emailAddress = $AlertEmailAddress; useCommonAlertSchema = $true }
    )
    armRoleReceivers = @(
        @{ name = 'subscription-owners'; roleId = $ownerRoleId; useCommonAlertSchema = $true }
        @{ name = 'subscription-contributors'; roleId = $contributorRoleId; useCommonAlertSchema = $true }
    )
} | ConvertTo-Json -Depth 5

az rest --method post --url $url --body $body --headers "Content-Type=application/json"
if ($LASTEXITCODE -ne 0) { throw "REST createNotifications failed." }
Write-Host ""
Write-Host "Notification dispatched via REST. Give email a minute or two to arrive." -ForegroundColor Green

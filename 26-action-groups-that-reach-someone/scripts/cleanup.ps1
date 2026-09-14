<#
.SYNOPSIS
    Deletes both demo resource groups and the subscription-scoped budget.
.EXAMPLE
    ./cleanup.ps1 -Force
    ./cleanup.ps1 -NameSuffix ab12 -Force
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$NameSuffix = '',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$suffix = if ($NameSuffix) { "-$NameSuffix" } else { '' }
$mgmtRg = "rg-contoso-demo-26-management$suffix"
$workloadRg = "rg-contoso-demo-26-workload$suffix"
$budgetName = "contoso-demo-26-monthly-budget$suffix"

if (-not $Force) {
    $answer = Read-Host "Delete $mgmtRg, $workloadRg and budget $budgetName? [y/N]"
    if ($answer -ne 'y') { Write-Host "Aborted."; return }
}

# Budgets are subscription-scoped and survive resource-group deletion.
if ($PSCmdlet.ShouldProcess($budgetName, 'Delete budget')) {
    az consumption budget delete --budget-name $budgetName 2>$null
    Write-Host "Budget $budgetName removed (if it existed)."
}

foreach ($rg in @($mgmtRg, $workloadRg)) {
    if ((az group exists --name $rg) -eq 'true') {
        if ($PSCmdlet.ShouldProcess($rg, 'Delete resource group')) {
            az group delete --name $rg --yes --no-wait
            Write-Host "Deletion started for $rg (--no-wait)."
        }
    }
    else {
        Write-Host "$rg does not exist. Skipping."
    }
}

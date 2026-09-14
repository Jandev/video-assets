<#
.SYNOPSIS
    Subscription-scope what-if. Shows what would change without deploying.
.EXAMPLE
    ./whatif.ps1 -AlertEmailAddress you@example.com
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

az deployment sub what-if `
    --location $Location `
    --template-file (Join-Path $infra 'main.bicep') `
    --parameters location=$Location `
                 nameSuffix=$NameSuffix `
                 alertEmailAddress=$AlertEmailAddress `
                 budgetStartDate=$BudgetStartDate

if ($LASTEXITCODE -ne 0) { throw "what-if failed." }

<#
.SYNOPSIS
    Proves queries/*.kql match the KQL embedded in log-alerts.bicep, and
    optionally runs each query against a live Log Analytics workspace.
.EXAMPLE
    ./validate-queries.ps1 -SyncOnly
    ./validate-queries.ps1 -ResourceGroup rg-contoso-demo-27
    ./validate-queries.ps1 -WorkspaceId 00000000-0000-0000-0000-000000000000
#>
[CmdletBinding()]
param(
    [string]$ResourceGroup = 'rg-contoso-demo-27',
    [string]$WorkspaceId,
    [switch]$SyncOnly
)

$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$failures = 0

# --- 1. Drift check -----------------------------------------------------------
$src = Get-Content (Join-Path $root 'infra/modules/log-alerts.bicep') -Raw
$mapping = [ordered]@{
    'serverErrorsQuery'         = 'server-errors.kql'
    'authorizationAnomalyQuery' = 'authorization-anomaly.kql'
    'dependencyFailuresQuery'   = 'dependency-failures.kql'
    'availabilityQuery'         = 'availability.kql'
}
$drift = $false
foreach ($var in $mapping.Keys) {
    $pattern = "var\s+$var\s*=\s*'''\r?\n(.*?)'''"
    $m = [regex]::Match($src, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)
    if (-not $m.Success) { Write-Host "        variable $var not found"; $drift = $true; continue }
    $path = Join-Path $root "queries/$($mapping[$var])"
    if (-not (Test-Path $path)) { Write-Host "        queries/$($mapping[$var]) missing"; $drift = $true; continue }
    # Compare on normalised line endings so a CRLF checkout does not false-fail.
    $embedded = $m.Groups[1].Value -replace "`r`n", "`n"
    $onDisk = (Get-Content $path -Raw) -replace "`r`n", "`n"
    if ($embedded -ne $onDisk) { Write-Host "        queries/$($mapping[$var]) has drifted from $var"; $drift = $true }
}
if ($drift) {
    Write-Host "  FAIL  KQL drift between queries/*.kql and log-alerts.bicep" -ForegroundColor Red
    $failures++
}
else {
    Write-Host "  PASS  queries/*.kql match the KQL embedded in log-alerts.bicep" -ForegroundColor Green
}

if ($SyncOnly) { if ($failures -eq 0) { exit 0 } else { exit 1 } }

# --- 2. Live validation -------------------------------------------------------
if (-not $WorkspaceId) {
    $WorkspaceId = az monitor log-analytics workspace list `
        --resource-group $ResourceGroup --query '[0].customerId' -o tsv 2>$null
}
if (-not $WorkspaceId) {
    Write-Host "  SKIP  no reachable workspace - pass -WorkspaceId <customerId> to validate live KQL"
    if ($failures -eq 0) { exit 0 } else { exit 1 }
}

Write-Host ""
Write-Host "Validating alert queries against workspace $WorkspaceId"
Write-Host ""
foreach ($file in Get-ChildItem (Join-Path $root 'queries') -Filter *.kql | Sort-Object Name) {
    $query = Get-Content $file.FullName -Raw
    $output = az monitor log-analytics query -w $WorkspaceId --analytics-query $query -o json 2>&1
    if ($LASTEXITCODE -eq 0) {
        $rows = ($output | ConvertFrom-Json).Count
        Write-Host ("  PASS  {0,-28} valid KQL, {1} row(s) returned" -f $file.Name, $rows) -ForegroundColor Green
    }
    else {
        Write-Host ("  FAIL  {0,-28}" -f $file.Name) -ForegroundColor Red
        $output | Select-Object -First 6 | ForEach-Object { Write-Host "        $_" }
        $failures++
    }
}

Write-Host ""
if ($failures -eq 0) { Write-Host "All queries are in sync and valid."; exit 0 }
Write-Host "$failures check(s) failed."
exit 1

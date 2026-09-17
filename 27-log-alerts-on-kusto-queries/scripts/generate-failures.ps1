<#
.SYNOPSIS
    Drives the failure-injection endpoints so a threshold is crossed inside one
    five-minute evaluation window. Works against a local or deployed URL.
.DESCRIPTION
    Scenarios:
      server-errors   GET /widgets/boom            (rule fires at >= 5)
      authorization   GET /orders/secret           (rule fires at >= 20)
      dependency      GET /widgets/{id}/supplier   (rule fires at >= 3)
      all             all three, back to back

    Availability is NOT here on purpose: that rule fires on the ABSENCE of
    traffic, so you trigger it by stopping the app, not by calling it.
.EXAMPLE
    ./generate-failures.ps1 -Url http://localhost:5027 -Scenario server-errors
    ./generate-failures.ps1 -Url https://my-api.example.com -Scenario all -Count 40
#>
[CmdletBinding()]
param(
    [string]$Url = 'http://localhost:5027',
    [ValidateSet('server-errors', 'authorization', 'dependency', 'all')]
    [string]$Scenario = 'server-errors',
    [int]$Count = 30,
    [int]$RatePerSec = 5
)

$ErrorActionPreference = 'Stop'
$Url = $Url.TrimEnd('/')
$delay = if ($RatePerSec -gt 0) { 1.0 / $RatePerSec } else { 0 }

function Invoke-Hit([string]$Path) {
    try {
        $resp = Invoke-WebRequest -Uri "$Url$Path" -SkipHttpErrorCheck -Method Get
        $code = $resp.StatusCode
    }
    catch {
        $code = '000'
    }
    Write-Host ("  {0,-32} -> {1}" -f $Path, $code)
    if ($delay -gt 0) { Start-Sleep -Seconds $delay }
}

function Invoke-Scenario([string]$Name) {
    switch ($Name) {
        'server-errors' {
            Write-Host "Scenario: server-errors ($Count x GET /widgets/boom) - rule fires at >= 5"
            1..$Count | ForEach-Object { Invoke-Hit '/widgets/boom' }
        }
        'authorization' {
            Write-Host "Scenario: authorization ($Count x GET /orders/secret) - rule fires at >= 20"
            1..$Count | ForEach-Object {
                if ($_ % 2 -eq 0) { Invoke-Hit '/orders/secret?forbidden=true' } else { Invoke-Hit '/orders/secret' }
            }
        }
        'dependency' {
            Write-Host "Scenario: dependency ($Count x GET /widgets/WIDGET-001/supplier) - rule fires at >= 3"
            1..$Count | ForEach-Object { Invoke-Hit '/widgets/WIDGET-001/supplier' }
        }
    }
}

Write-Host "Target : $Url"
Write-Host "Rate   : $RatePerSec req/s"
Write-Host ""

if ($Scenario -eq 'all') {
    Invoke-Scenario 'server-errors'; Write-Host ''
    Invoke-Scenario 'authorization'; Write-Host ''
    Invoke-Scenario 'dependency'
}
else {
    Invoke-Scenario $Scenario
}

Write-Host ""
Write-Host "Done. Telemetry reaches Log Analytics within a few minutes; the rule then"
Write-Host "evaluates on its PT5M cycle. Expect the notification several minutes later,"
Write-Host "not instantly - see docs/script.md for how to film this honestly."

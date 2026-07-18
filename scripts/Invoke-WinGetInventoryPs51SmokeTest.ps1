#Requires -Version 5.1
<#
.SYNOPSIS
    PS 5.1 entry smoke: inventory demo hops to pwsh (Intune host floor).

.DESCRIPTION
    **Safety tier: 1**

    Asserts Windows PowerShell 5.1, then runs Invoke-WinGetInventoryDemo.ps1.
    Expects the demo to re-launch under pwsh (Get-WinGetPackage is pwsh-only).
    Exit 0 on success; 2 module missing under pwsh; 6 pwsh missing; else fail.

.PARAMETER AgentSummary
    Emit one-line summary instead of full JSON from the demo.
#>
[CmdletBinding()]
param(
    [switch] $AgentSummary
)

$ErrorActionPreference = 'Stop'

$v = $PSVersionTable.PSVersion
if ($v.Major -ne 5) {
    Write-Output ("WGA-PS51-SMOKE-SKIP expected PS 5.x got {0}" -f $v)
    exit 0
}

$demo = Join-Path $PSScriptRoot 'Invoke-WinGetInventoryDemo.ps1'
if (-not (Test-Path -LiteralPath $demo)) {
    throw "Demo script not found: $demo"
}

Write-Output ("WGA-PS51-SMOKE-HOST {0} (expects hop to pwsh)" -f $v)

$demoArgs = @{
    Json = $true
}
if ($AgentSummary) {
    $demoArgs = @{ AgentSummary = $true }
}

& $demo @demoArgs
$code = $LASTEXITCODE
if ($null -eq $code) {
    $code = 0
}

if ($code -eq 0) {
    Write-Output 'WGA-PS51-SMOKE-OK (5.1 entry -> pwsh inventory)'
}
elseif ($code -eq 2) {
    Write-Output 'WGA-PS51-SMOKE missing Microsoft.WinGet.Client under pwsh - Install-Module via pwsh / Ensure-WinGetClient -InstallIfMissing'
}
elseif ($code -eq 6) {
    Write-Output 'WGA-PS51-SMOKE pwsh not found - install PowerShell 7+ machine-wide'
}
else {
    Write-Output ("WGA-PS51-SMOKE-FAIL exit={0}" -f $code)
}

exit $code

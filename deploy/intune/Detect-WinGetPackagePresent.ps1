#Requires -Version 5.1
<#
.SYNOPSIS
    Intune detect stub: package present (WGA-007 Presence).

.DESCRIPTION
    **Safety tier: 1**

    Exit 0 when the package is installed (InstalledCurrent or
    InstalledUpdateAvailable); exit 1 when NotInstalled.
    Calls scripts/Invoke-WinGetPackageDetect.ps1 — set WGA_AUDIT_ROOT to the
    winget-audit product root on the device, or run from a repo checkout
    (stub resolves ../../scripts). Must stay <= 51200 bytes.

.PARAMETER PackageId
    WinGet package Id. Defaults to env WGA_PACKAGE_ID.
#>
[CmdletBinding()]
param(
    [string] $PackageId = $env:WGA_PACKAGE_ID
)

$ErrorActionPreference = 'Stop'
if ([string]::IsNullOrWhiteSpace($PackageId)) {
    Write-Output 'WGA: set -PackageId or env WGA_PACKAGE_ID'
    exit 4
}

$root = $env:WGA_AUDIT_ROOT
if ([string]::IsNullOrWhiteSpace($root)) {
    $root = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}
$detect = Join-Path $root 'scripts\Invoke-WinGetPackageDetect.ps1'
if (-not (Test-Path -LiteralPath $detect)) {
    Write-Output ("WGA: detect script missing at {0}; set WGA_AUDIT_ROOT" -f $detect)
    exit 3
}

& $detect -PackageId $PackageId -Purpose Presence -Exact -Plane B -AgentSummary
exit $LASTEXITCODE

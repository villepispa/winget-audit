#Requires -Version 5.1
<#
.SYNOPSIS
    Detect one WinGet package: presence and/or up-to-date (WGA-007).

.DESCRIPTION
  **Safety tier: 1**

  Read-only. Classifies NotInstalled / InstalledCurrent /
  InstalledUpdateAvailable per docs/detection-semantics.md.
  Default Plane B: WindowsApps winget.exe list WITHOUT --upgrade-available
  (empty upgrade list must not mean not-installed). Optional Plane A when
  pwsh + Microsoft.WinGet.Client are available (-Plane A|Auto).
  Lab entry: imports src/WinGet.Audit then calls Invoke-WgaDetectPackage.
  Intune upload: rebuild via scripts/Build-WgaIntuneScripts.ps1.

.PARAMETER PackageId
    WinGet package Id (e.g. Microsoft.WindowsAppRuntime.1.5).

.PARAMETER Purpose
    Presence — exit 0 if installed (any state except NotInstalled).
    UpToDate — exit 0 only if InstalledCurrent (NotInstalled and
    InstalledUpdateAvailable are non-compliant).

.PARAMETER Exact
    Pass --exact to winget list (Plane B).

.PARAMETER Plane
    B (default), A (Client/pwsh), or Auto (A if pwsh+module else B).

.PARAMETER Json
    Write probe JSON (default).

.PARAMETER AgentSummary
    One-line summary on Write-Output.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string] $PackageId,

    [ValidateSet('Presence', 'UpToDate')]
    [string] $Purpose = 'Presence',

    [switch] $Exact,

    [ValidateSet('A', 'B', 'Auto')]
    [string] $Plane = 'B',

    [switch] $Json,

    [switch] $AgentSummary
)

$ErrorActionPreference = 'Stop'
if (-not $PSBoundParameters.ContainsKey('Json')) {
    $Json = $true
}

$moduleManifest = Join-Path $PSScriptRoot '..\src\WinGet.Audit\WinGet.Audit.psd1'
Import-Module $moduleManifest -Force

$invokeParams = @{
    PackageId    = $PackageId
    Purpose      = $Purpose
    Exact        = $Exact
    Plane        = $Plane
    Json         = $Json
    AgentSummary = $AgentSummary
}
Invoke-WgaDetectPackage @invokeParams

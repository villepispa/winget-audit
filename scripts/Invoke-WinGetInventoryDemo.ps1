#Requires -Version 5.1
<#
.SYNOPSIS
    Demo WinGet inventory + version compare via Microsoft.WinGet.Client (JSON).

.DESCRIPTION
    **Safety tier: 1**

    Read-only. Emits a probe-shaped JSON summary of packages with
    IsUpdateAvailable, plus compare notes. Does not install or upgrade packages.
    Get-WinGetPackage requires PowerShell 7+ (Microsoft.WinGet.Client). When
    started under Windows PowerShell 5.1 (Intune entry host), this script
    re-launches itself under pwsh if available (exit 6 if pwsh missing).
    SYSTEM matrix: install the module *as SYSTEM under pwsh* (see
    docs/system-matrix.md). Optionally uses Spine.Automation probe envelopes.

.PARAMETER Json
    Write JSON to stdout (default).

.PARAMETER AgentSummary
    One-line agent summary (Write-Output; dual-host safe).
#>
[CmdletBinding()]
param(
    [switch] $Json,
    [switch] $AgentSummary
)

$ErrorActionPreference = 'Stop'
if (-not $PSBoundParameters.ContainsKey('Json')) {
    $Json = $true
}

# Microsoft.WinGet.Client package cmdlets are not supported in Windows PowerShell.
if ($PSVersionTable.PSVersion.Major -lt 6) {
    $pwshCmd = Get-Command -Name pwsh -ErrorAction SilentlyContinue
    if (-not $pwshCmd) {
        Write-Output (@{
            ok         = $false
            exitCode   = 6
            safetyTier = 1
            summary    = 'Get-WinGetPackage requires PowerShell 7+ (pwsh not found)'
            data       = @{
                hint = 'Install PowerShell 7+ and Microsoft.WinGet.Client under pwsh; Intune entry may stay on 5.1 and hop via this script'
            }
        } | ConvertTo-Json -Depth 5 -Compress)
        exit 6
    }
    $relaunchArgs = @(
        '-NoProfile',
        '-ExecutionPolicy', 'Bypass',
        '-File', $PSCommandPath
    )
    if ($Json) { $relaunchArgs += '-Json' }
    if ($AgentSummary) { $relaunchArgs += '-AgentSummary' }
    & $pwshCmd.Source @relaunchArgs
    exit $LASTEXITCODE
}

function Import-WgaSpineProbeOptional {
    if (Get-Command -Name Write-SpineProbeEnvelope -ErrorAction SilentlyContinue) {
        return $true
    }

    $candidates = @()
    if (-not [string]::IsNullOrWhiteSpace($env:WGA_SPINE_MODULE_PATH)) {
        $candidates += $env:WGA_SPINE_MODULE_PATH
    }
    $sibling = Join-Path $PSScriptRoot '..\..\spine-automation\src\Spine.Automation'
    $candidates += $sibling
    $candidates += 'Spine.Automation'

    foreach ($c in $candidates) {
        try {
            if ($c -eq 'Spine.Automation') {
                Import-Module -Name Spine.Automation -ErrorAction Stop
            }
            elseif (Test-Path -LiteralPath $c) {
                Import-Module -Name $c -ErrorAction Stop
            }
            else {
                continue
            }
            if (Get-Command -Name Write-SpineProbeEnvelope -ErrorAction SilentlyContinue) {
                return $true
            }
        }
        catch {
            continue
        }
    }
    return $false
}

function Write-WgaProbeOutput {
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [object] $Data,

        [int] $ExitCode = 0,

        [int] $SafetyTier = 1,

        [string] $Summary = '',

        [string] $SummaryLine = '',

        [switch] $UseSpine
    )

    if ($UseSpine) {
        $spParams = @{
            Data       = $Data
            ExitCode   = $ExitCode
            SafetyTier = $SafetyTier
            Summary    = $Summary
        }
        if ($AgentSummary) {
            $spParams['AgentSummary'] = $true
            if (-not [string]::IsNullOrWhiteSpace($SummaryLine)) {
                $spParams['SummaryLine'] = $SummaryLine
            }
        }
        Write-SpineProbeEnvelope @spParams
        return
    }

    $envelope = [ordered]@{
        ok         = ($ExitCode -eq 0)
        exitCode   = $ExitCode
        safetyTier = $SafetyTier
        summary    = $Summary
        data       = $Data
    }
    if ($Json -or -not $AgentSummary) {
        $envelope | ConvertTo-Json -Depth 8
    }
    if ($AgentSummary) {
        # Write-Output (not Write-Information) so PS 5.1 shows the line by default.
        if (-not [string]::IsNullOrWhiteSpace($SummaryLine)) {
            Write-Output $SummaryLine
        }
        else {
            Write-Output $Summary
        }
    }
}

$useSpine = Import-WgaSpineProbeOptional

$who = [Security.Principal.WindowsIdentity]::GetCurrent()
$isSystem = $who.User.Value -eq 'S-1-5-18'
$psMajor = [int]$PSVersionTable.PSVersion.Major
# Not $psEdition — that name collides with automatic $PSEdition (case-insensitive).
$hostEdition = 'Desktop'
if ($PSVersionTable.ContainsKey('PSEdition')) {
    $hostEdition = [string]$PSVersionTable.PSEdition
}

$contextHint = if ($isSystem) {
    'Install as SYSTEM (not Admin): Invoke-WinGetInventoryDemoAsSystem.ps1 -BootstrapModule - or Install-Module under PsExec -s / Intune SYSTEM host. Admin CurrentUser is invisible to SYSTEM. Install per host (5.1 vs pwsh module paths differ).'
}
else {
    'Install-Module -Name Microsoft.WinGet.Client -Scope CurrentUser -Force (run under the same host: powershell.exe vs pwsh)'
}

$mod = Get-Module -ListAvailable -Name Microsoft.WinGet.Client |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $mod) {
    Write-WgaProbeOutput `
        -Data @{
            hint       = $contextHint
            context    = $(if ($isSystem) { 'SYSTEM' } else { 'User' })
            identity   = $who.Name
            psVersion  = [string]$PSVersionTable.PSVersion
            psEdition  = $hostEdition
        } `
        -ExitCode 2 `
        -Summary 'Microsoft.WinGet.Client not installed' `
        -SummaryLine 'WINGET-AUDIT-DEMO missing-module exit=2' `
        -UseSpine:$useSpine
    exit 2
}

Import-Module Microsoft.WinGet.Client -ErrorAction Stop

$updates = @(
    Get-WinGetPackage -ErrorAction Stop |
        Where-Object { $_.IsUpdateAvailable }
)

$packages = @(
    $updates | ForEach-Object {
        $available = $null
        $availList = @($_.AvailableVersions)
        if ($availList.Count -gt 0) {
            $available = [string]$availList[0]
        }
        $installed = [string]$_.InstalledVersion
        $cmp = $null
        if ($available -and $installed) {
            try {
                $cmp = [version]$available -gt [version]$installed
            }
            catch {
                $cmp = 'non-[version] - use SemanticVersion / custom compare'
            }
        }
        [ordered]@{
            Id                  = $_.Id
            Name                = $_.Name
            Source              = $_.Source
            InstalledVersion    = $installed
            AvailableVersion    = $available
            IsUpdateAvailable   = [bool]$_.IsUpdateAvailable
            AvailableLooksNewer = $cmp
        }
    }
)

$context = $(if ($isSystem) { 'SYSTEM' } else { 'User' })
$data = [ordered]@{
    moduleVersion = [string]$mod.Version
    context       = $context
    identity      = $who.Name
    psVersion     = [string]$PSVersionTable.PSVersion
    psEdition     = $hostEdition
    psMajor       = $psMajor
    packageCount  = $packages.Count
    packages      = $packages
    spineUsed     = [bool]$useSpine
    notes         = @(
        'Primary path is Microsoft.WinGet.Client - not winget.exe text parse.',
        'IsUpdateAvailable means applicable upgrade, not merely newer catalog version.',
        'CLI text fallback: Convert-WingetTextToObject in src/WinGet.Audit.',
        'Optional Spine envelope: docs/spine-consumption.md',
        'Inventory API requires pwsh 7+; Windows PowerShell 5.1 entry hops to pwsh (WGA-004).'
    )
}

$summary = "WinGet.Audit demo: $($packages.Count) package(s) with IsUpdateAvailable"
$line = "WINGET-AUDIT-DEMO ok packages={0} context={1} spine={2} ps={3}" -f `
    $packages.Count, $context, $useSpine, $PSVersionTable.PSVersion

Write-WgaProbeOutput `
    -Data $data `
    -ExitCode 0 `
    -Summary $summary `
    -SummaryLine $line `
    -UseSpine:$useSpine

exit 0

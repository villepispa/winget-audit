#Requires -Version 5.1
<#
.SYNOPSIS
    Plane B inventory: WindowsApps winget.exe list + CLI text parse (no pwsh).

.DESCRIPTION
    **Safety tier: 1**

    Read-only. Resolves winget.exe under WindowsApps (SYSTEM-safe), runs
    `winget list` with --accept-source-agreements (and --no-progress /
    --disable-interactivity when supported), parses table text, emits
    probe-shaped JSON.
    For fleets without PowerShell 7. Prefer Plane A (WinGet.Client) when pwsh
    is available. See docs/system-matrix.md.

.PARAMETER Query
    Optional package query passed to `winget list <Query>`.
    For lab/smoke prefer `WindowsAppRuntime` (common on Win11 fleets).

.PARAMETER UpdatesOnly
    Keep rows that have a non-empty Available column (upgrade candidates).

.PARAMETER Json
    Write JSON to stdout (default).

.PARAMETER AgentSummary
    One-line summary on Write-Output.
#>
[CmdletBinding()]
param(
    [string] $Query,

    [switch] $UpdatesOnly,

    [switch] $Json,

    [switch] $AgentSummary
)

$ErrorActionPreference = 'Stop'
if (-not $PSBoundParameters.ContainsKey('Json')) {
    $Json = $true
}

$moduleManifest = Join-Path $PSScriptRoot '..\src\WinGet.Audit\WinGet.Audit.psd1'
Import-Module $moduleManifest -Force

$who = [Security.Principal.WindowsIdentity]::GetCurrent()
$isSystem = $who.User.Value -eq 'S-1-5-18'
$context = if ($isSystem) { 'SYSTEM' } else { 'User' }
$hostEdition = 'Desktop'
if ($PSVersionTable.ContainsKey('PSEdition')) {
    $hostEdition = [string]$PSVersionTable.PSEdition
}

function Write-WgaCliProbe {
    param(
        [AllowNull()][object] $Data,
        [int] $ExitCode,
        [string] $Summary,
        [string] $SummaryLine
    )
    $envelope = [ordered]@{
        ok         = ($ExitCode -eq 0)
        exitCode   = $ExitCode
        safetyTier = 1
        summary    = $Summary
        data       = $Data
    }
    if ($Json -or -not $AgentSummary) {
        $envelope | ConvertTo-Json -Depth 8
    }
    if ($AgentSummary) {
        Write-Output $SummaryLine
    }
}

try {
    $wingetExe = Resolve-WinGetExe
}
catch {
    Write-WgaCliProbe `
        -Data @{
            hint     = $_.Exception.Message
            context  = $context
            identity = $who.Name
            plane    = 'B'
        } `
        -ExitCode 2 `
        -Summary 'winget.exe not found under WindowsApps' `
        -SummaryLine 'WINGET-AUDIT-CLI missing-winget exit=2'
    exit 2
}

# list supports --accept-source-agreements (not --accept-package-agreements).
$baseArgs = @('list', '--accept-source-agreements')
if (-not [string]::IsNullOrWhiteSpace($Query)) {
    $baseArgs += $Query
}

# Prefer quiet + stable sort (1.29+); strip flags older builds reject.
$attemptArgSets = New-Object 'System.Collections.Generic.List[object]'
if ($UpdatesOnly) {
    [void]$attemptArgSets.Add(@($baseArgs + @('--upgrade-available', '--no-progress', '--sort', 'id', '--disable-interactivity')))
    [void]$attemptArgSets.Add(@($baseArgs + @('--upgrade-available', '--no-progress', '--sort', 'id')))
    [void]$attemptArgSets.Add(@($baseArgs + @('--upgrade-available', '--no-progress', '--disable-interactivity')))
    [void]$attemptArgSets.Add(@($baseArgs + @('--upgrade-available', '--no-progress')))
    [void]$attemptArgSets.Add(@($baseArgs + @('--upgrade-available', '--disable-interactivity')))
    [void]$attemptArgSets.Add(@($baseArgs + @('--upgrade-available')))
}
[void]$attemptArgSets.Add(@($baseArgs + @('--no-progress', '--sort', 'id', '--disable-interactivity')))
[void]$attemptArgSets.Add(@($baseArgs + @('--no-progress', '--sort', 'id')))
[void]$attemptArgSets.Add(@($baseArgs + @('--no-progress', '--disable-interactivity')))
[void]$attemptArgSets.Add(@($baseArgs + @('--no-progress')))
[void]$attemptArgSets.Add(@($baseArgs + @('--disable-interactivity')))
[void]$attemptArgSets.Add(@($baseArgs))

$rawLines = @()
$wingetExit = 1
foreach ($attempt in $attemptArgSets) {
    try {
        $rawLines = & $wingetExe @attempt 2>&1 | ForEach-Object { "$_" }
        $wingetExit = $LASTEXITCODE
    }
    catch {
        $wingetExit = 1
    }
    if ($wingetExit -eq 0) {
        break
    }
}

if ($wingetExit -ne 0) {
    Write-WgaCliProbe `
        -Data @{
            wingetExe = $wingetExe
            exitCode  = $wingetExit
            output    = ($rawLines | Select-Object -First 40)
            context   = $context
            plane     = 'B'
        } `
        -ExitCode 3 `
        -Summary ("winget list failed exit={0}" -f $wingetExit) `
        -SummaryLine ("WINGET-AUDIT-CLI winget-fail exit={0}" -f $wingetExit)
    exit 3
}

try {
    $packages = @($rawLines | Convert-WingetTextToObject)
}
catch {
    Write-WgaCliProbe `
        -Data @{
            wingetExe = $wingetExe
            error     = $_.Exception.Message
            output    = ($rawLines | Select-Object -First 40)
            context   = $context
            plane     = 'B'
        } `
        -ExitCode 1 `
        -Summary 'Failed to parse winget list table' `
        -SummaryLine 'WINGET-AUDIT-CLI parse-fail exit=1'
    exit 1
}

if ($UpdatesOnly) {
    $packages = @(
        $packages | Where-Object {
            $avail = $_.Available
            -not [string]::IsNullOrWhiteSpace([string]$avail)
        }
    )
}

$normalized = @(
    $packages | ForEach-Object {
        $installed = [string]$_.Version
        $available = [string]$_.Available
        $cmp = $null
        if ($available -and $installed) {
            try {
                $cmp = [version]$available -gt [version]$installed
            }
            catch {
                $cmp = 'non-[version] - compare as string / SemVer later'
            }
        }
        [ordered]@{
            Id                  = [string]$_.Id
            Name                = [string]$_.Name
            Source              = [string]$_.Source
            InstalledVersion    = $installed
            AvailableVersion    = $available
            AvailableLooksNewer = $cmp
        }
    }
)

$data = [ordered]@{
    plane         = 'B'
    wingetExe     = $wingetExe
    context       = $context
    identity      = $who.Name
    psVersion     = [string]$PSVersionTable.PSVersion
    psEdition     = $hostEdition
    packageCount  = $normalized.Count
    updatesOnly   = [bool]$UpdatesOnly
    packages      = $normalized
    notes         = @(
        'Plane B: WindowsApps winget.exe + CLI text parse (no Microsoft.WinGet.Client).',
        'Prefer Plane A Get-WinGetPackage when pwsh is available.',
        'PATH / App Execution Alias winget under SYSTEM is unreliable.'
    )
}

$summary = "WinGet.Audit CLI demo: $($normalized.Count) package(s) plane=B"
$line = "WINGET-AUDIT-CLI ok packages={0} context={1} plane=B ps={2}" -f `
    $normalized.Count, $context, $PSVersionTable.PSVersion

Write-WgaCliProbe -Data $data -ExitCode 0 -Summary $summary -SummaryLine $line
exit 0

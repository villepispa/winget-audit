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

. (Join-Path $PSScriptRoot 'Get-WgaDetectionState.ps1')

$who = [Security.Principal.WindowsIdentity]::GetCurrent()
$isSystem = $who.User.Value -eq 'S-1-5-18'
$context = if ($isSystem) { 'SYSTEM' } else { 'User' }

function Write-WgaDetectProbe {
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

function Test-WgaPwshWinGetClient {
    $pwsh = Get-Command -Name pwsh -ErrorAction SilentlyContinue
    if (-not $pwsh) { return $false }
    $check = & $pwsh.Source -NoProfile -Command {
        $ErrorActionPreference = 'Stop'
        try {
            Import-Module Microsoft.WinGet.Client -ErrorAction Stop
            return 'ok'
        }
        catch { return 'no' }
    }
    return ($check -eq 'ok')
}

function Invoke-WgaDetectPlaneA {
    param([string] $Id)

    $pwsh = (Get-Command -Name pwsh -ErrorAction Stop).Source
    $script = @'
param([string]$Id)
$ErrorActionPreference = "Stop"
Import-Module Microsoft.WinGet.Client -ErrorAction Stop
$pkg = @(Get-WinGetPackage -Id $Id -ErrorAction SilentlyContinue)
if ($pkg.Count -eq 0) {
    @{ installed = $false; id = $Id } | ConvertTo-Json -Compress
    exit 0
}
$p = $pkg[0]
@{
    installed = $true
    id = [string]$p.Id
    name = [string]$p.Name
    source = [string]$p.Source
    installedVersion = [string]$p.InstalledVersion
    availableVersion = if ($p.AvailableVersions -and $p.AvailableVersions.Count) { [string]$p.AvailableVersions[0] } else { "" }
    isUpdateAvailable = [bool]$p.IsUpdateAvailable
} | ConvertTo-Json -Compress
'@
    $tmp = Join-Path $env:TEMP ("wga-detect-a-{0}.ps1" -f ([guid]::NewGuid().ToString('N')))
    try {
        Set-Content -LiteralPath $tmp -Value $script -Encoding UTF8
        $json = & $pwsh -NoProfile -File $tmp -Id $Id
        return ($json | ConvertFrom-Json)
    }
    finally {
        Remove-Item -LiteralPath $tmp -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-WgaDetectPlaneB {
    param(
        [string] $Id,
        [switch] $UseExact
    )

    . (Join-Path $PSScriptRoot 'Resolve-WinGetExe.ps1')
    . (Join-Path $PSScriptRoot 'fallback\Convert-WingetTextToObject.ps1')

    $wingetExe = Resolve-WinGetExe
    $baseArgs = @('list', '--id', $Id, '--accept-source-agreements')
    if ($UseExact) {
        $baseArgs += '--exact'
    }

    $attemptArgSets = New-Object 'System.Collections.Generic.List[object]'
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

    # winget often exits non-zero when no package matches — treat as NotInstalled
    if ($wingetExit -ne 0) {
        $joined = ($rawLines | Out-String)
        if ($joined -match 'No installed package found|No packages found') {
            return @{
                installed = $false
                id        = $Id
                wingetExe = $wingetExe
                wingetExit = $wingetExit
            }
        }
        throw ("winget list failed exit={0}" -f $wingetExit)
    }

    $packages = @()
    try {
        $packages = @($rawLines | Convert-WingetTextToObject)
    }
    catch {
        # Empty / header-only table → not installed
        return @{
            installed = $false
            id        = $Id
            wingetExe = $wingetExe
            wingetExit = $wingetExit
        }
    }

    $match = @(
        $packages | Where-Object {
            [string]$_.Id -eq $Id -or
            ($UseExact -eq $false -and [string]$_.Id -like ("*{0}*" -f $Id))
        }
    ) | Select-Object -First 1

    if (-not $match) {
        return @{
            installed  = $false
            id         = $Id
            wingetExe  = $wingetExe
            wingetExit = $wingetExit
        }
    }

    return @{
        installed         = $true
        id                = [string]$match.Id
        name              = [string]$match.Name
        source            = [string]$match.Source
        installedVersion  = [string]$match.Version
        availableVersion  = [string]$match.Available
        wingetExe         = $wingetExe
        wingetExit        = $wingetExit
    }
}

$resolvedPlane = $Plane
if ($Plane -eq 'Auto') {
    $resolvedPlane = if (Test-WgaPwshWinGetClient) { 'A' } else { 'B' }
}

$raw = $null
try {
    if ($resolvedPlane -eq 'A') {
        if ($PSVersionTable.PSVersion.Major -lt 6 -and -not (Get-Command pwsh -ErrorAction SilentlyContinue)) {
            Write-WgaDetectProbe `
                -Data @{ hint = 'Plane A requires pwsh'; packageId = $PackageId } `
                -ExitCode 6 `
                -Summary 'Plane A requires PowerShell 7+' `
                -SummaryLine 'WINGET-AUDIT-DETECT plane-a-no-pwsh exit=6'
            exit 6
        }
        $raw = Invoke-WgaDetectPlaneA -Id $PackageId
    }
    else {
        $raw = Invoke-WgaDetectPlaneB -Id $PackageId -UseExact:$Exact
    }
}
catch {
    $code = 3
    if ("$($_.Exception.Message)" -match 'No Desktop App Installer|winget.exe missing') {
        $code = 2
    }
    Write-WgaDetectProbe `
        -Data @{
            packageId = $PackageId
            purpose   = $Purpose
            plane     = $resolvedPlane
            context   = $context
            error     = $_.Exception.Message
        } `
        -ExitCode $code `
        -Summary $_.Exception.Message `
        -SummaryLine ("WINGET-AUDIT-DETECT fail exit={0}" -f $code)
    exit $code
}

$installedFlag = [bool]$raw.installed
$isUpdate = $null
if ($resolvedPlane -eq 'A' -and $null -ne $raw.isUpdateAvailable) {
    $isUpdate = [bool]$raw.isUpdateAvailable
}

$stateParams = @{
    PackageId         = $PackageId
    Installed         = $installedFlag
    InstalledVersion  = [string]$raw.installedVersion
    AvailableVersion  = [string]$raw.availableVersion
}
if ($null -ne $isUpdate) {
    $stateParams['IsUpdateAvailable'] = $isUpdate
}

$state = Resolve-WgaDetectionState @stateParams
$result = New-WgaDetectionResult `
    -State $state `
    -Purpose $Purpose `
    -PackageId $(if ($raw.id) { [string]$raw.id } else { $PackageId }) `
    -Plane $resolvedPlane `
    -InstalledVersion ([string]$raw.installedVersion) `
    -AvailableVersion ([string]$raw.availableVersion) `
    -Name ([string]$raw.name) `
    -Source ([string]$raw.source)

$data = [ordered]@{
    detection = $result
    context   = $context
    identity  = $who.Name
    notes     = @(
        'Presence and UpToDate are orthogonal - see docs/detection-semantics.md.',
        'Plane B uses list without --upgrade-available for presence.'
    )
}

$exitCode = [int]$result.exitCode
$summary = "WGA detect {0}: state={1} purpose={2} plane={3}" -f `
    $PackageId, $state, $Purpose, $resolvedPlane
$line = "WINGET-AUDIT-DETECT state={0} purpose={1} compliant={2} plane={3} id={4}" -f `
    $state, $Purpose, $result.compliant, $resolvedPlane, $PackageId

Write-WgaDetectProbe -Data $data -ExitCode $exitCode -Summary $summary -SummaryLine $line
exit $exitCode

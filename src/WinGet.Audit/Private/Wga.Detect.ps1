#Requires -Version 5.1
<#
.SYNOPSIS
    Plane A/B detect helpers for one WinGet package.

.DESCRIPTION
    **Safety tier: 1**

    Private helpers for Invoke-WgaDetectPackage. No $PSScriptRoot dotsources —
    safe inside the module and inside the Intune bundle concat.
    Depends on Resolve-WinGetExe, Convert-WingetTextToObject, and the
    detection-state functions (loaded with this file in the bundle, or via
    the module root).
#>

function Write-WgaDetectProbe {
    param(
        [AllowNull()][object] $Data,
        [int] $ExitCode,
        [string] $Summary,
        [string] $SummaryLine,
        [switch] $Json,
        [switch] $AgentSummary
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
                installed  = $false
                id         = $Id
                wingetExe  = $wingetExe
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
        return @{
            installed  = $false
            id         = $Id
            wingetExe  = $wingetExe
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

    # StrictMode-safe: winget list rows omit Available when no update column.
    $note = {
        param($Obj, [string] $Name)
        $prop = $Obj.PSObject.Properties[$Name]
        if ($null -eq $prop) { return '' }
        return [string]$prop.Value
    }

    return @{
        installed         = $true
        id                = & $note $match 'Id'
        name              = & $note $match 'Name'
        source            = & $note $match 'Source'
        installedVersion  = & $note $match 'Version'
        availableVersion  = & $note $match 'Available'
        wingetExe         = $wingetExe
        wingetExit        = $wingetExit
    }
}

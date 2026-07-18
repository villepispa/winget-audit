#Requires -Version 5.1
<#
.SYNOPSIS
    Re-run the inventory demo under SYSTEM via PsExec (lab matrix).

.DESCRIPTION
    **Safety tier: 1**

    If already running as SYSTEM, invokes the demo in-process (same host; the
    demo hops 5.1 -> pwsh when needed). Otherwise requires elevation + PsExec -s.
    Skips cleanly when PsExec or elevation is missing (exit 3 / 4).

    Get-WinGetPackage requires PowerShell 7+. -BootstrapModule always installs
    Microsoft.WinGet.Client under **pwsh as SYSTEM**. -WindowsPowerShell only
    changes the PsExec *entry* host to powershell.exe (Intune-shaped); the demo
    then hops to pwsh.

.PARAMETER PsExecPath
    Full path to PsExec.exe when not on PATH.

.PARAMETER DemoScript
    Path to Invoke-WinGetInventoryDemo.ps1 (default: sibling script).

.PARAMETER Json
    Pass -Json through to the demo (default on).

.PARAMETER AgentSummary
    Pass -AgentSummary through / emit wrapper summary.

.PARAMETER BootstrapModule
    Install-Module Microsoft.WinGet.Client under SYSTEM via **pwsh** (network).

.PARAMETER SkipDemo
    With -BootstrapModule, install only and exit (do not run the demo).

.PARAMETER WindowsPowerShell
    PsExec entry via Windows PowerShell 5.1 (Intune-shaped). Inventory still
    runs on pwsh after the demo's hop. Bootstrap always uses pwsh.
#>
[CmdletBinding()]
param(
    [string] $PsExecPath,

    [string] $DemoScript,

    [switch] $Json,

    [switch] $AgentSummary,

    [switch] $BootstrapModule,

    [switch] $SkipDemo,

    [switch] $WindowsPowerShell
)

$ErrorActionPreference = 'Stop'
if (-not $PSBoundParameters.ContainsKey('Json')) {
    $Json = $true
}

if ([string]::IsNullOrWhiteSpace($DemoScript)) {
    $DemoScript = Join-Path $PSScriptRoot 'Invoke-WinGetInventoryDemo.ps1'
}
$demo = Resolve-Path -LiteralPath $DemoScript -ErrorAction Stop

$who = [Security.Principal.WindowsIdentity]::GetCurrent()
$isSystem = $who.User.Value -eq 'S-1-5-18'
$moduleName = 'Microsoft.WinGet.Client'
$installCommand = "Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop"

function Test-WgaIsElevated {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($id)
    return $principal.IsInRole(
        [Security.Principal.WindowsBuiltInRole]::Administrator
    )
}

function Find-WgaPsExec {
    param([string] $Explicit)
    if (-not [string]::IsNullOrWhiteSpace($Explicit) -and (Test-Path -LiteralPath $Explicit)) {
        return (Resolve-Path -LiteralPath $Explicit).Path
    }
    $cmd = Get-Command -Name 'PsExec.exe', 'psexec.exe' -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

function Resolve-WgaEnginePath {
    param([switch] $PreferWindowsPowerShell)
    if ($PreferWindowsPowerShell) {
        $sysRoot = $env:SystemRoot
        if ([string]::IsNullOrWhiteSpace($sysRoot)) {
            $sysRoot = 'C:\Windows'
        }
        $ps51 = Join-Path $sysRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
        if (-not (Test-Path -LiteralPath $ps51)) {
            throw "Windows PowerShell not found at $ps51"
        }
        return $ps51
    }
    $pwshCmd = Get-Command -Name pwsh -ErrorAction SilentlyContinue
    if (-not $pwshCmd) {
        throw 'pwsh not found on PATH (required for Get-WinGetPackage / module bootstrap)'
    }
    return $pwshCmd.Source
}

function Invoke-WgaBootstrapModuleHere {
    # Always install into the pwsh module tree - Get-WinGetPackage is pwsh-only.
    if ($PSVersionTable.PSVersion.Major -ge 6) {
        if ($AgentSummary) {
            Write-Output 'WGA-SYSTEM-MATRIX bootstrap Install-Module as SYSTEM under pwsh (CurrentUser)'
        }
        try {
            Install-Module -Name $moduleName -Scope CurrentUser -Force -AllowClobber -ErrorAction Stop
        }
        catch {
            if ($AgentSummary) {
                Write-Output ("WGA-SYSTEM-MATRIX bootstrap-failed: {0}" -f $_.Exception.Message)
            }
            else {
                [ordered]@{
                    ok         = $false
                    exitCode   = 5
                    safetyTier = 1
                    summary    = 'Bootstrap Microsoft.WinGet.Client failed under SYSTEM'
                    data       = @{ error = $_.Exception.Message }
                } | ConvertTo-Json -Depth 5
            }
            exit 5
        }
        return
    }

    $pwshExe = Resolve-WgaEnginePath
    if ($AgentSummary) {
        Write-Output ("WGA-SYSTEM-MATRIX bootstrap via pwsh from PS 5.1 host engine={0}" -f $pwshExe)
    }
    & $pwshExe -NoProfile -ExecutionPolicy Bypass -Command $installCommand
    if ($LASTEXITCODE -ne 0) {
        if ($AgentSummary) {
            Write-Output ("WGA-SYSTEM-MATRIX bootstrap-failed exit={0}" -f $LASTEXITCODE)
        }
        exit 5
    }
}

function Invoke-WgaDemoHere {
    $demoArgs = @()
    if ($Json) { $demoArgs += '-Json' }
    if ($AgentSummary) { $demoArgs += '-AgentSummary' }
    & $demo.Path @demoArgs
    exit $LASTEXITCODE
}

if ($isSystem) {
    if ($BootstrapModule) {
        Invoke-WgaBootstrapModuleHere
        if ($SkipDemo) {
            if ($AgentSummary) {
                Write-Output 'WGA-SYSTEM-MATRIX bootstrap-ok skip-demo'
            }
            exit 0
        }
    }
    Invoke-WgaDemoHere
}

if (-not (Test-WgaIsElevated)) {
    $msg = 'WGA-SYSTEM-MATRIX skip: elevation required for PsExec -s'
    if ($AgentSummary) { Write-Output $msg }
    else {
        [ordered]@{
            ok         = $false
            exitCode   = 4
            safetyTier = 1
            summary    = $msg
            data       = @{ context = 'User'; hint = 'Run elevated PowerShell' }
        } | ConvertTo-Json -Depth 5
    }
    exit 4
}

$psexec = Find-WgaPsExec -Explicit $PsExecPath
if (-not $psexec) {
    $msg = 'WGA-SYSTEM-MATRIX skip: PsExec.exe not found on PATH'
    if ($AgentSummary) { Write-Output $msg }
    else {
        [ordered]@{
            ok         = $false
            exitCode   = 3
            safetyTier = 1
            summary    = $msg
            data       = @{
                hint = 'Install Sysinternals PsTools or pass -PsExecPath'
            }
        } | ConvertTo-Json -Depth 5
    }
    exit 3
}

# Bootstrap always under pwsh (inventory API host). Entry may be 5.1 for Intune shape.
$bootstrapExe = Resolve-WgaEnginePath
$entryExe = Resolve-WgaEnginePath -PreferWindowsPowerShell:$WindowsPowerShell

if ($BootstrapModule) {
    $bootList = @(
        '-accepteula',
        '-s',
        '-nobanner',
        $bootstrapExe,
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-Command',
        $installCommand
    )
    if ($AgentSummary) {
        Write-Output ("WGA-SYSTEM-MATRIX bootstrap via PsExec engine={0}" -f $bootstrapExe)
    }
    & $psexec @bootList
    if ($LASTEXITCODE -ne 0) {
        if ($AgentSummary) {
            Write-Output ("WGA-SYSTEM-MATRIX bootstrap-failed exit={0}" -f $LASTEXITCODE)
        }
        exit 5
    }
    if ($SkipDemo) {
        if ($AgentSummary) {
            Write-Output 'WGA-SYSTEM-MATRIX bootstrap-ok skip-demo'
        }
        exit 0
    }
}

$argList = @(
    '-accepteula',
    '-s',
    '-nobanner',
    $entryExe,
    '-NoProfile',
    '-ExecutionPolicy',
    'Bypass',
    '-File',
    $demo.Path
)
if ($Json) { $argList += '-Json' }
if ($AgentSummary) { $argList += '-AgentSummary' }

if ($AgentSummary) {
    Write-Output ("WGA-SYSTEM-MATRIX launching via PsExec entry={0} (inventory hops to pwsh if entry is 5.1)" -f $entryExe)
}

& $psexec @argList
$code = $LASTEXITCODE
if ($AgentSummary) {
    if ($code -eq 2) {
        Write-Output 'WGA-SYSTEM-MATRIX hint: module missing for SYSTEM pwsh - re-run with -BootstrapModule (Admin Install-Module is not enough)'
    }
    if ($code -eq 6) {
        Write-Output 'WGA-SYSTEM-MATRIX hint: pwsh not found under SYSTEM - install PowerShell 7+ machine-wide'
    }
    Write-Output ("WGA-SYSTEM-MATRIX done exit={0}" -f $code)
}
exit $code

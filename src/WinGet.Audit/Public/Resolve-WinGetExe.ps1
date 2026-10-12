#Requires -Version 5.1

function Resolve-WinGetExe {
    <#
    .SYNOPSIS
        Resolve a usable Desktop App Installer winget.exe path.

    .DESCRIPTION
        **Safety tier: 1**

        Resolution order:
        1. Glob under Program Files\WindowsApps (ACL allows — typical SYSTEM)
        2. Get-AppxPackage InstallLocation (User often cannot enumerate WindowsApps)
        3. Non-SYSTEM only: %LOCALAPPDATA%\Microsoft\WindowsApps\winget.exe
           (SCCM user-collection detection — see docs/detection-semantics.md)

        For SYSTEM inventory prefer (1)/(2). Do not use the user LocalAppData
        App Execution Alias as the SYSTEM Plane B entry.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [ValidateSet('x64', 'x86', 'arm64')]
        [string] $Architecture = 'x64'
    )

    $pattern = Join-Path $env:ProgramFiles (
        "WindowsApps\Microsoft.DesktopAppInstaller_*_{0}__8wekyb3d8bbwe" -f $Architecture
    )
    $dirs = @(Resolve-Path -Path $pattern -ErrorAction SilentlyContinue |
        Sort-Object -Property Path)

    if ($dirs.Count -gt 0) {
        $exe = Join-Path $dirs[-1].Path 'winget.exe'
        if (Test-Path -LiteralPath $exe) {
            return $exe
        }
    }

    # Non-admin User often cannot enumerate WindowsApps; Appx still exposes InstallLocation.
    $archToken = switch ($Architecture) {
        'x64' { 'X64' }
        'x86' { 'X86' }
        'arm64' { 'Arm64' }
        default { 'X64' }
    }

    $pkgs = @(Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue)
    if ($pkgs.Count -eq 0) {
        $pkgs = @(Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -AllUsers -ErrorAction SilentlyContinue)
    }

    $pkgs = @(
        $pkgs |
            Where-Object {
                $_.Architecture.ToString() -eq $archToken -or
                $_.Architecture.ToString() -eq 'Neutral'
            } |
            Sort-Object -Property Version
    )

    if ($pkgs.Count -eq 0) {
        $pkgs = @(
            @(Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction SilentlyContinue) +
            @(Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -AllUsers -ErrorAction SilentlyContinue) |
                Sort-Object -Property Version -Unique
        )
    }

    if ($pkgs.Count -gt 0) {
        $exe = Join-Path $pkgs[-1].InstallLocation 'winget.exe'
        if (Test-Path -LiteralPath $exe) {
            return $exe
        }
    }

    # SCCM user-collection detection: script runs as the user; Program Files\WindowsApps
    # may be unreadable even when InstallLocation is known. User App Execution Alias path
    # is the pragmatic fallback. Skip under SYSTEM (wrong context for inventory).
    $sid = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    if ($sid -ne 'S-1-5-18') {
        $userAlias = Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'
        if (Test-Path -LiteralPath $userAlias) {
            return $userAlias
        }
    }

    throw ("No usable winget.exe (glob {0}; Appx InstallLocation unreadable; user LocalAppData alias missing)" -f $pattern)
}

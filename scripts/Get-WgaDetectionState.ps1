#Requires -Version 5.1
<#
.SYNOPSIS
    Classify WinGet package presence vs update-available (WGA-007).

.DESCRIPTION
    **Safety tier: 1**

    Dot-source this file, then call Resolve-WgaDetectionState /
    Get-WgaDetectionExitCode. Pure logic — no winget.exe / module calls.
    See docs/detection-semantics.md.
#>

function Resolve-WgaDetectionState {
    [CmdletBinding()]
    [OutputType([string])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSReviewUnusedParameter',
        'PackageId',
        Justification = 'Public classifier contract — callers pass Id for logging/API symmetry; state uses Installed/versions only.')]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $PackageId,

        [switch] $Installed,

        [AllowEmptyString()]
        [string] $InstalledVersion,

        [AllowEmptyString()]
        [string] $AvailableVersion,

        # When set (Plane A), overrides AvailableVersion string heuristic.
        [object] $IsUpdateAvailable = $null
    )

    if (-not $Installed) {
        return 'NotInstalled'
    }

    $update = $false
    if ($null -ne $IsUpdateAvailable) {
        $update = [bool]$IsUpdateAvailable
    }
    elseif (-not [string]::IsNullOrWhiteSpace($AvailableVersion)) {
        $update = $true
        if (-not [string]::IsNullOrWhiteSpace($InstalledVersion)) {
            try {
                $update = ([version]$AvailableVersion) -gt ([version]$InstalledVersion)
            }
            catch {
                # Non-[version] strings (SemVer with pre-release, etc.): treat non-empty Available as update signal
                $update = $true
            }
        }
    }

    if ($update) {
        return 'InstalledUpdateAvailable'
    }
    return 'InstalledCurrent'
}

function Get-WgaDetectionExitCode {
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('NotInstalled', 'InstalledCurrent', 'InstalledUpdateAvailable')]
        [string] $State,

        [Parameter(Mandatory)]
        [ValidateSet('Presence', 'UpToDate')]
        [string] $Purpose
    )

    switch ($Purpose) {
        'Presence' {
            if ($State -eq 'NotInstalled') { return 1 }
            return 0
        }
        'UpToDate' {
            # Not installed = non-compliant for "must be current" (install first or fail).
            if ($State -eq 'InstalledCurrent') { return 0 }
            return 1
        }
    }
}

function New-WgaDetectionResult {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('NotInstalled', 'InstalledCurrent', 'InstalledUpdateAvailable')]
        [string] $State,

        [Parameter(Mandatory)]
        [ValidateSet('Presence', 'UpToDate')]
        [string] $Purpose,

        [Parameter(Mandatory)]
        [string] $PackageId,

        [ValidateSet('A', 'B')]
        [string] $Plane = 'B',

        [AllowEmptyString()]
        [string] $InstalledVersion = '',

        [AllowEmptyString()]
        [string] $AvailableVersion = '',

        [AllowEmptyString()]
        [string] $Name = '',

        [AllowEmptyString()]
        [string] $Source = ''
    )

    $exitCode = Get-WgaDetectionExitCode -State $State -Purpose $Purpose
    return [ordered]@{
        state             = $State
        purpose           = $Purpose
        packageId         = $PackageId
        name              = $Name
        source            = $Source
        installedVersion  = $InstalledVersion
        availableVersion  = $AvailableVersion
        plane             = $Plane
        compliant         = ($exitCode -eq 0)
        exitCode          = $exitCode
    }
}

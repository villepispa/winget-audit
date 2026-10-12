#Requires -Version 5.1

function Resolve-WgaDetectionState {
    <#
    .SYNOPSIS
        Classify WinGet package presence vs update-available.

    .DESCRIPTION
        **Safety tier: 1**

        Pure logic — no winget.exe or Microsoft.WinGet.Client calls.
        Returns NotInstalled, InstalledCurrent, or InstalledUpdateAvailable.
        See docs/detection-semantics.md.
    #>
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

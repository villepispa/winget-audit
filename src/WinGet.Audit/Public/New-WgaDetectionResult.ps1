#Requires -Version 5.1

function New-WgaDetectionResult {
    <#
    .SYNOPSIS
        Build the detection result record (state, versions, compliance, exit code).

    .DESCRIPTION
        **Safety tier: 1**

        Calls Get-WgaDetectionExitCode. No winget process.
    #>
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

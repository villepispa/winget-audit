#Requires -Version 5.1

function Get-WgaDetectionExitCode {
    <#
    .SYNOPSIS
        Map a detection state and purpose to an Intune-style exit code.

    .DESCRIPTION
        **Safety tier: 1**

        Presence: 0 when installed, 1 when NotInstalled.
        UpToDate: 0 only for InstalledCurrent.
    #>
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

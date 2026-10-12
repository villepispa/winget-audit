#Requires -Version 5.1

function Invoke-WgaDetectPackage {
    <#
    .SYNOPSIS
        Detect one WinGet package (Presence or UpToDate) and exit with the compliance code.

    .DESCRIPTION
        **Safety tier: 1**

        Read-only. Classifies NotInstalled / InstalledCurrent /
        InstalledUpdateAvailable. Writes a probe envelope, then exits.
        Default plane is B (WindowsApps winget.exe). Plane A hops to pwsh
        when Microsoft.WinGet.Client is available.

        Exit codes: 0 compliant, 1 non-compliant, 2 winget.exe missing,
        3 detect failure, 6 Plane A requested without pwsh.
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

    if (-not $PSBoundParameters.ContainsKey('Json')) {
        $Json = $true
    }

    $who = [Security.Principal.WindowsIdentity]::GetCurrent()
    $isSystem = $who.User.Value -eq 'S-1-5-18'
    $context = if ($isSystem) { 'SYSTEM' } else { 'User' }

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
                    -SummaryLine 'WINGET-AUDIT-DETECT plane-a-no-pwsh exit=6' `
                    -Json:$Json -AgentSummary:$AgentSummary
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
        if ("$($_.Exception.Message)" -match 'No Desktop App Installer|winget.exe missing|No usable winget') {
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
            -SummaryLine ("WINGET-AUDIT-DETECT fail exit={0}" -f $code) `
            -Json:$Json -AgentSummary:$AgentSummary
        exit $code
    }

    $installedFlag = [bool]$raw.installed
    $isUpdate = $null
    if ($resolvedPlane -eq 'A' -and $null -ne $raw.isUpdateAvailable) {
        $isUpdate = [bool]$raw.isUpdateAvailable
    }

    $stateParams = @{
        PackageId        = $PackageId
        Installed        = $installedFlag
        InstalledVersion = [string]$raw.installedVersion
        AvailableVersion = [string]$raw.availableVersion
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

    Write-WgaDetectProbe -Data $data -ExitCode $exitCode -Summary $summary `
        -SummaryLine $line -Json:$Json -AgentSummary:$AgentSummary
    exit $exitCode
}

#Requires -Version 5.1
Describe 'WGA-007 detection classifier' {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $harness = Join-Path $repoRoot 'tests\helpers\Import-WgaTestHarness.ps1'
        if (-not (Test-Path -LiteralPath $harness)) {
            $repoRoot = Split-Path -Parent $PSScriptRoot
            $harness = Join-Path $repoRoot 'tests\helpers\Import-WgaTestHarness.ps1'
        }
        . $harness
    }

    It 'NotInstalled when no match' {
        Resolve-WgaDetectionState -PackageId 'X.Y' | Should -Be 'NotInstalled'
    }

    It 'InstalledCurrent when installed and no Available' {
        Resolve-WgaDetectionState -PackageId 'X.Y' -Installed -InstalledVersion '1.0.0' |
            Should -Be 'InstalledCurrent'
    }

    It 'InstalledUpdateAvailable when Available is newer [version]' {
        Resolve-WgaDetectionState -PackageId 'X.Y' -Installed `
            -InstalledVersion '1.0.0' -AvailableVersion '1.1.0' |
            Should -Be 'InstalledUpdateAvailable'
    }

    It 'InstalledCurrent when Available equals Installed' {
        Resolve-WgaDetectionState -PackageId 'X.Y' -Installed `
            -InstalledVersion '1.0.0' -AvailableVersion '1.0.0' |
            Should -Be 'InstalledCurrent'
    }

    It 'InstalledUpdateAvailable honors IsUpdateAvailable true' {
        Resolve-WgaDetectionState -PackageId 'X.Y' -Installed -InstalledVersion '1.0.0' `
            -IsUpdateAvailable $true |
            Should -Be 'InstalledUpdateAvailable'
    }

    It 'InstalledCurrent honors IsUpdateAvailable false even if Available set' {
        Resolve-WgaDetectionState -PackageId 'X.Y' -Installed -InstalledVersion '1.0.0' `
            -AvailableVersion '9.9.9' -IsUpdateAvailable $false |
            Should -Be 'InstalledCurrent'
    }

    It 'Presence exit 0 when installed' {
        Get-WgaDetectionExitCode -State InstalledCurrent -Purpose Presence | Should -Be 0
        Get-WgaDetectionExitCode -State InstalledUpdateAvailable -Purpose Presence | Should -Be 0
        Get-WgaDetectionExitCode -State NotInstalled -Purpose Presence | Should -Be 1
    }

    It 'UpToDate exit 0 only when InstalledCurrent' {
        Get-WgaDetectionExitCode -State InstalledCurrent -Purpose UpToDate | Should -Be 0
        Get-WgaDetectionExitCode -State InstalledUpdateAvailable -Purpose UpToDate | Should -Be 1
        Get-WgaDetectionExitCode -State NotInstalled -Purpose UpToDate | Should -Be 1
    }
}

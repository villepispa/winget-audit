#Requires -Version 5.1
<#
.SYNOPSIS
    Dot-source WinGet.Audit Private then Public for Pester.

.DESCRIPTION
    **Safety tier: 1**

    Same order as the Intune bundle so tests can call private helpers
    (Get-WgaWingetCell) without Import-Module. $PSScriptRoot is tests/helpers.
#>

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..\..')
$moduleRoot = Join-Path $projectRoot 'src\WinGet.Audit'

$privateOrder = @(
    'Wga.Cli.ps1'
    'Wga.Detect.ps1'
)

foreach ($name in $privateOrder) {
    . (Join-Path $moduleRoot "Private\$name")
}

$publicOrder = @(
    'Resolve-WgaDetectionState.ps1'
    'Get-WgaDetectionExitCode.ps1'
    'New-WgaDetectionResult.ps1'
    'Resolve-WinGetExe.ps1'
    'Convert-WingetTextToObject.ps1'
    'Invoke-WgaDetectPackage.ps1'
)

foreach ($name in $publicOrder) {
    . (Join-Path $moduleRoot "Public\$name")
}

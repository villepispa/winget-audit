# WinGet.Audit — module root
# Private order matches scripts/intune/bundle-order.json (Intune concat).

$public = Join-Path $PSScriptRoot 'Public'
$private = Join-Path $PSScriptRoot 'Private'

$privateFiles = @(
    'Wga.Cli.ps1'
    'Wga.Detect.ps1'
)

foreach ($name in $privateFiles) {
    $path = Join-Path $private $name
    if (Test-Path -LiteralPath $path) {
        . $path
    }
}

Get-ChildItem -Path $public -Filter '*.ps1' -ErrorAction SilentlyContinue |
    ForEach-Object { . $_.FullName }

Export-ModuleMember -Function @(
    'Resolve-WgaDetectionState'
    'Get-WgaDetectionExitCode'
    'New-WgaDetectionResult'
    'Resolve-WinGetExe'
    'Convert-WingetTextToObject'
    'Invoke-WgaDetectPackage'
)

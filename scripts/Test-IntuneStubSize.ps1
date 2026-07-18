#Requires -Version 5.1
<#
.SYNOPSIS
    Fail if any deploy/intune/*.ps1 exceeds the EAC 50 KB ceiling.

.DESCRIPTION
    **Safety tier: 1**

    Enterprise App Catalog PowerShell install/uninstall overrides are capped at
    51200 bytes. Scans deploy/intune for .ps1 files and exits non-zero when any
    file is over the limit. Emits JSON by default for agent/CI consumption.

.PARAMETER MaxBytes
    Ceiling in bytes (default 51200).

.PARAMETER StubDirectory
    Directory to scan (default: ../deploy/intune relative to this script).

.PARAMETER Json
    Write JSON envelope to stdout (default when neither switch is set).

.PARAMETER AgentSummary
    One-line summary instead of / in addition to structured checks.
#>
[CmdletBinding()]
param(
    [int] $MaxBytes = 51200,

    [string] $StubDirectory,

    [switch] $Json,

    [switch] $AgentSummary
)

$ErrorActionPreference = 'Stop'
if (-not $PSBoundParameters.ContainsKey('Json') -and -not $AgentSummary) {
    $Json = $true
}

if ([string]::IsNullOrWhiteSpace($StubDirectory)) {
    $StubDirectory = Join-Path $PSScriptRoot '..\deploy\intune'
}

$resolved = Resolve-Path -LiteralPath $StubDirectory -ErrorAction Stop
$files = @(
    Get-ChildItem -LiteralPath $resolved.Path -Filter '*.ps1' -File |
        Sort-Object Name
)

$violations = @()
$okFiles = @()
foreach ($f in $files) {
    $row = [ordered]@{
        name  = $f.Name
        bytes = [int]$f.Length
        path  = $f.FullName
    }
    if ($f.Length -gt $MaxBytes) {
        $violations += $row
    }
    else {
        $okFiles += $row
    }
}

$exitCode = 0
$summary = "Intune stub size OK: $($okFiles.Count) file(s) ≤ $MaxBytes bytes"
if ($violations.Count -gt 0) {
    $exitCode = 1
    $names = ($violations | ForEach-Object { '{0}={1}' -f $_.name, $_.bytes }) -join ', '
    $summary = "Intune stub size FAIL: $names (max $MaxBytes)"
}

$result = [ordered]@{
    ok         = ($exitCode -eq 0)
    exitCode   = $exitCode
    safetyTier = 1
    summary    = $summary
    data       = [ordered]@{
        maxBytes    = $MaxBytes
        stubDirectory = [string]$resolved.Path
        fileCount   = $files.Count
        ok          = $okFiles
        violations  = $violations
    }
}

if ($Json) {
    $result | ConvertTo-Json -Depth 6
}
if ($AgentSummary) {
    Write-Output ("WGA-STUB-SIZE ok={0} files={1} violations={2} exit={3}" -f `
        ($exitCode -eq 0), $files.Count, $violations.Count, $exitCode)
}

exit $exitCode

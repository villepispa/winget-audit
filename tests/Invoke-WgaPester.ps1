#Requires -Version 5.1
<#
.SYNOPSIS
  Runs WinGet.Audit Pester suites under tests/unit.

.DESCRIPTION
  **Safety tier: 1** (executes unit tests; no WinGet mutations).

  Uses the Pester configuration object (v5/v6). Default path is tests/unit
  beside this script. Exit code follows Pester unless -AgentSummary is set.

.PARAMETER TestPath
  One or more test paths (files or directories). Default: tests/unit.

.PARAMETER AgentSummary
  Write exactly one line to the success stream so agents can use a single
  pwsh -NoProfile -File invocation:
  WGA-PESTER-OK passed=N on exit 0; WGA-PESTER-FAIL exit=N … on failure.
  When set, Pester Exit is disabled so this script owns the exit code.

.EXAMPLE
  pwsh -NoProfile -File .\tests\Invoke-WgaPester.ps1

.EXAMPLE
  pwsh -NoProfile -File .\tests\Invoke-WgaPester.ps1 -AgentSummary

.NOTES
  Install: Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force
#>
[CmdletBinding()]
param(
    [string[]] $TestPath = @(
        (Join-Path $PSScriptRoot 'unit')
    ),

    [switch] $AgentSummary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$pester = Get-Module Pester -ListAvailable |
    Sort-Object Version -Descending |
    Select-Object -First 1
if (-not $pester) {
    if ($AgentSummary) {
        Write-Output 'WGA-PESTER-FAIL exit=2 detail=Pester-not-installed'
        exit 2
    }
    throw 'Pester is not installed. Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser'
}
if ($pester.Version -lt [version]'5.5.0') {
    if ($AgentSummary) {
        Write-Output ("WGA-PESTER-FAIL exit=2 detail=Pester-too-old version={0}" -f $pester.Version)
        exit 2
    }
    throw "Pester $($pester.Version) is too old. Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser"
}

Import-Module Pester -MinimumVersion $pester.Version -Force
Write-Host "Using Pester $($pester.Version)"

$projectRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

$config = New-PesterConfiguration
$config.Run.Path = $TestPath
$config.Run.RepoRoot = $projectRoot.Path
$config.Run.Exit = -not $AgentSummary
$config.Run.PassThru = [bool]$AgentSummary
$config.Output.Verbosity = 'Detailed'

$result = Invoke-Pester -Configuration $config

if ($AgentSummary) {
    $failed = 0
    $passed = 0
    if ($null -ne $result) {
        if ($null -ne $result.FailedCount) { $failed = [int]$result.FailedCount }
        if ($null -ne $result.PassedCount) { $passed = [int]$result.PassedCount }
        # Pester 6 may leave *Count null on the top-level object; derive from Tests.
        if (($passed -eq 0) -and ($failed -eq 0) -and ($null -ne $result.Tests)) {
            $tests = @($result.Tests)
            $passed = @($tests | Where-Object { $_.Result -eq 'Passed' }).Count
            $failed = @($tests | Where-Object { $_.Result -eq 'Failed' }).Count
        }
        if (($passed -eq 0) -and ($failed -eq 0) -and ($null -ne $result.Passed) -and ($null -ne $result.Failed)) {
            $passed = @($result.Passed).Count
            $failed = @($result.Failed).Count
        }
    }
    if ($failed -gt 0) {
        Write-Output ("WGA-PESTER-FAIL exit=1 failed={0} passed={1}" -f $failed, $passed)
        exit 1
    }
    Write-Output ("WGA-PESTER-OK passed={0}" -f $passed)
    exit 0
}

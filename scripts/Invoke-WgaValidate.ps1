#Requires -Version 5.1
<#
.SYNOPSIS
  Repo-root validate gate: Intune stub size, Pester, PSScriptAnalyzer.

.DESCRIPTION
  **Safety tier: 1** (tests + static analysis; no WinGet mutations).

  Ordered stages: Gallery dep check → stub size → Pester (tests/unit) →
  ScriptAnalyzer. Prefer this entry for agents and CI discovery (WGA-012).
  Does not Install-Module (no network); prints the Install-Module pair when
  Pester or PSScriptAnalyzer is missing.

.PARAMETER SkipLint
  Skip PSScriptAnalyzer (e.g. when the module is unavailable locally).

.PARAMETER AgentSummary
  One success-stream line:
  WGA-VALIDATE-OK | WGA-VALIDATE-FAIL stage=<name> exit=N

.EXAMPLE
  pwsh -NoProfile -File .\scripts\Invoke-WgaValidate.ps1 -AgentSummary

.NOTES
  Cold host (CurrentUser):
  Install-Module Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck
  Install-Module PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck
#>
[CmdletBinding()]
param(
    [switch] $SkipLint,

    [switch] $AgentSummary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')
$stubScript = Join-Path $PSScriptRoot 'Test-IntuneStubSize.ps1'
$pesterScript = Join-Path $repoRoot.Path 'tests\Invoke-WgaPester.ps1'
$lintScript = Join-Path $PSScriptRoot 'Invoke-WgaScriptAnalyzer.ps1'

function Test-WgaValidateDependency {
    $missing = @()
    $pester = Get-Module -ListAvailable -Name Pester |
        Sort-Object Version -Descending |
        Select-Object -First 1
    if (-not $pester -or $pester.Version -lt [version]'5.5.0') {
        $missing += 'Pester>=5.5'
    }
    if (-not $SkipLint) {
        if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
            $missing += 'PSScriptAnalyzer'
        }
    }
    if ($missing.Count -eq 0) {
        return
    }

    $hint = @(
        'Install-Module -Name Pester -MinimumVersion 5.5.0 -Scope CurrentUser -Force -SkipPublisherCheck'
        'Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force -SkipPublisherCheck'
    ) -join '; '
    if ($AgentSummary) {
        Write-Output (
            'WGA-VALIDATE-FAIL stage=deps exit=2 missing={0}' -f (
                ($missing -join ',')
            )
        )
    }
    else {
        Write-Error (
            "Missing Gallery modules: {0}. Run: {1}" -f (
                ($missing -join ', '),
                $hint
            )
        ) -ErrorAction Continue
    }
    exit 2
}

function Invoke-WgaStage {
    param(
        [Parameter(Mandatory)]
        [string] $Name,

        [Parameter(Mandatory)]
        [string] $ScriptPath,

        [string[]] $ArgumentList = @()
    )

    if (-not (Test-Path -LiteralPath $ScriptPath)) {
        throw "Missing stage script ($Name): $ScriptPath"
    }

    $pwshArgs = @('-NoProfile', '-File', $ScriptPath) + $ArgumentList
    if ($AgentSummary) {
        $pwshArgs += '-AgentSummary'
    }

    & pwsh @pwshArgs
    $code = $LASTEXITCODE
    if ($null -eq $code) { $code = 0 }
    if ($code -ne 0) {
        if ($AgentSummary) {
            Write-Output ("WGA-VALIDATE-FAIL stage={0} exit={1}" -f $Name, $code)
        }
        exit $code
    }
}

Test-WgaValidateDependency

Invoke-WgaStage -Name 'stub-size' -ScriptPath $stubScript
Invoke-WgaStage -Name 'pester' -ScriptPath $pesterScript

if (-not $SkipLint) {
    Invoke-WgaStage -Name 'lint' -ScriptPath $lintScript
}

if ($AgentSummary) {
    Write-Output 'WGA-VALIDATE-OK'
}
exit 0

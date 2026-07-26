#Requires -Version 5.1
<#
.SYNOPSIS
  Run PSScriptAnalyzer on WinGet.Audit product scripts.

.DESCRIPTION
  **Safety tier: 1** (read-only static analysis; no network).

  Scans scripts/ (excluding _drafts) and deploy/intune/ using the repo-root
  PSScriptAnalyzerSettings.psd1. Does not depend on .cursor catalog lint.

.PARAMETER Path
  Optional extra roots or files. Default: scripts + deploy/intune under repo root.

.PARAMETER SettingsPath
  Optional settings .psd1. Default: ../PSScriptAnalyzerSettings.psd1.

.PARAMETER AgentSummary
  One success-stream line for bare pwsh -File:
  WGA-LINT-OK findings=N | WGA-LINT-FAIL exit=1 findings=N |
  WGA-LINT-MISS (module missing, exit 2).

.EXAMPLE
  pwsh -NoProfile -File .\scripts\Invoke-WgaScriptAnalyzer.ps1 -AgentSummary
#>
[CmdletBinding()]
param(
    [string[]] $Path = @(),

    [string] $SettingsPath = '',

    [switch] $AgentSummary
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Resolve-Path (Join-Path $PSScriptRoot '..')

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    if ($AgentSummary) {
        Write-Output 'WGA-LINT-MISS'
    }
    Write-Error 'PSScriptAnalyzer is not installed. Install-Module -Name PSScriptAnalyzer -Scope CurrentUser -Force' -ErrorAction Continue
    exit 2
}

Import-Module PSScriptAnalyzer -ErrorAction Stop

if ([string]::IsNullOrWhiteSpace($SettingsPath)) {
    $SettingsPath = Join-Path $repoRoot.Path 'PSScriptAnalyzerSettings.psd1'
}
if (-not (Test-Path -LiteralPath $SettingsPath)) {
    if ($AgentSummary) {
        Write-Output 'WGA-LINT-FAIL exit=1 detail=settings-missing'
    }
    throw "Settings not found: $SettingsPath"
}

$targets = @()
if ($Path -and $Path.Count -gt 0) {
    foreach ($p in $Path) {
        if (-not [System.IO.Path]::IsPathRooted($p)) {
            $p = Join-Path $repoRoot.Path $p
        }
        if (-not (Test-Path -LiteralPath $p)) {
            throw "Path not found: $p"
        }
        $targets += (Resolve-Path -LiteralPath $p).Path
    }
}
else {
    $targets += (Join-Path $repoRoot.Path 'scripts')
    $targets += (Join-Path $repoRoot.Path 'deploy\intune')
}

$fileList = New-Object System.Collections.Generic.List[string]
foreach ($target in $targets) {
    $item = Get-Item -LiteralPath $target
    if ($item.PSIsContainer) {
        Get-ChildItem -LiteralPath $target -Filter '*.ps1' -File -Recurse |
            ForEach-Object {
                $full = $_.FullName
                $norm = $full.Replace('\', '/')
                if ($norm -match '(^|/)(_drafts|_archive)(/|$)') { return }
                [void]$fileList.Add($full)
            }
    }
    else {
        [void]$fileList.Add($item.FullName)
    }
}

$uniqueFiles = @($fileList | Sort-Object -Unique)
$findings = @()
foreach ($scriptPath in $uniqueFiles) {
    $findings += @(
        Invoke-ScriptAnalyzer -Path $scriptPath -Settings $SettingsPath -Severity @('Error', 'Warning')
    )
}

$count = @($findings).Count
if ($count -gt 0) {
    $findings | Format-Table -AutoSize RuleName, Severity, ScriptName, Line, Message | Out-Host
    if ($AgentSummary) {
        Write-Output ("WGA-LINT-FAIL exit=1 findings={0}" -f $count)
    }
    exit 1
}

if ($AgentSummary) {
    Write-Output ("WGA-LINT-OK findings=0 files={0}" -f $uniqueFiles.Count)
}
exit 0

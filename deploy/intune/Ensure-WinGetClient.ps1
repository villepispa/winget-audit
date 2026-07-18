#Requires -Version 5.1
<#
.SYNOPSIS
    EAC/Intune stub: ensure Microsoft.WinGet.Client is available for pwsh.

.DESCRIPTION
    **Safety tier: 2**

    Thin Enterprise App Catalog / Win32 PowerShell override stub. Get-WinGetPackage
    requires PowerShell 7+, so this stub checks/installs the module under **pwsh**
    (even when Intune launches Windows PowerShell 5.1). Under SYSTEM uses
    -Scope CurrentUser for the SYSTEM pwsh profile. Never imports Spine.
    Must stay <= 51200 bytes (EAC PowerShell script ceiling).

.PARAMETER WhatIf
    Report intent only. Exit 1 when the module is missing under pwsh.

.PARAMETER InstallIfMissing
    When set and the module is absent under pwsh, run Install-Module via pwsh.
#>
[CmdletBinding()]
param(
    [switch] $WhatIf,
    [switch] $InstallIfMissing
)

$ErrorActionPreference = 'Stop'
$moduleName = 'Microsoft.WinGet.Client'

function Write-WgaStubLine {
    param([Parameter(Mandatory)][string] $Message)
    Write-Output $Message
}

function Resolve-WgaPwshPath {
    $cmd = Get-Command -Name pwsh -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    $candidates = @(
        (Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'),
        (Join-Path ${env:ProgramFiles(x86)} 'PowerShell\7\pwsh.exe')
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path -LiteralPath $c)) { return $c }
    }
    return $null
}

$isSystem = [Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18'
$installScope = if ($isSystem) { 'CurrentUser' } else { 'AllUsers' }
$pwshExe = Resolve-WgaPwshPath
if (-not $pwshExe) {
    Write-WgaStubLine 'WGA-STUB missing pwsh - install PowerShell 7+ (Get-WinGetPackage is pwsh-only)'
    exit 2
}

$probeCmd = @"
`$m = Get-Module -ListAvailable -Name '$moduleName' | Sort-Object Version -Descending | Select-Object -First 1
if (`$null -eq `$m) { exit 1 }
Write-Output ([string]`$m.Version)
exit 0
"@
$probe = & $pwshExe -NoProfile -ExecutionPolicy Bypass -Command $probeCmd 2>&1
$probeCode = $LASTEXITCODE

if ($probeCode -eq 0) {
    $ver = ([string]$probe).Trim()
    Write-WgaStubLine ("WGA-STUB ready module={0} version={1} engine=pwsh identitySystem={2}" -f $moduleName, $ver, $isSystem)
    exit 0
}

if ($WhatIf) {
    Write-WgaStubLine ("WGA-STUB missing module={0} under pwsh; would Install-Module -Scope {1}" -f $moduleName, $installScope)
    exit 1
}

if (-not $InstallIfMissing) {
    Write-WgaStubLine ("WGA-STUB missing module={0} under pwsh; pass -InstallIfMissing (Scope={1})" -f $moduleName, $installScope)
    exit 1
}

$installCmd = "Install-Module -Name '$moduleName' -Scope $installScope -Force -AllowClobber -ErrorAction Stop"
& $pwshExe -NoProfile -ExecutionPolicy Bypass -Command $installCmd
if ($LASTEXITCODE -ne 0) {
    Write-WgaStubLine ("WGA-STUB install-failed module={0} scope={1} via pwsh" -f $moduleName, $installScope)
    exit 2
}

$after = & $pwshExe -NoProfile -ExecutionPolicy Bypass -Command $probeCmd 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-WgaStubLine ("WGA-STUB install-reported-ok but module still missing under pwsh={0}" -f $moduleName)
    exit 2
}

Write-WgaStubLine ("WGA-STUB installed module={0} version={1} scope={2} engine=pwsh" -f $moduleName, ([string]$after).Trim(), $installScope)
exit 0

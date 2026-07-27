# --- Intune detection entry (merged by Build-WgaIntuneScripts.ps1 from Detect-WinGetPackagePresent.Entry.ps1) ---
# One question: Presence (WGA-007). Set WGA_PACKAGE_ID on the device / assignment.
$ErrorActionPreference = 'Stop'

$WgaPackageId = $env:WGA_PACKAGE_ID
if ([string]::IsNullOrWhiteSpace($WgaPackageId)) {
    Write-Output 'WGA: set env WGA_PACKAGE_ID (WinGet package Id)'
    exit 4
}

$WgaExact = $true
$WgaPlane = 'B'
if (-not [string]::IsNullOrWhiteSpace($env:WGA_DETECT_PLANE)) {
    $WgaPlane = $env:WGA_DETECT_PLANE
}

Invoke-WgaDetectPackage -PackageId $WgaPackageId -Purpose Presence `
    -Exact:$WgaExact -Plane $WgaPlane -AgentSummary

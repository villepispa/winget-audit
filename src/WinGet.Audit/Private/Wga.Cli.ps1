#Requires -Version 5.1
<#
.SYNOPSIS
    Fixed-width cell slice for the winget CLI table parser.

.DESCRIPTION
    **Safety tier: 1**

    Private helper for Convert-WingetTextToObject. Not exported.
    Loaded before Public sources (module and Intune bundle).
#>

function Get-WgaWingetCell {
    param(
        [string] $Row,
        [int] $Start,
        [int] $NextStart,
        [switch] $LegacyCellCleanup
    )
    if ($Start -ge $Row.Length) {
        return ''
    }
    $len = if ($NextStart -lt 0) {
        $Row.Length - $Start
    }
    else {
        [Math]::Min($NextStart, $Row.Length) - $Start
    }
    if ($len -le 0) {
        return ''
    }
    $cell = $Row.Substring($Start, $len).Trim()
    if (-not $LegacyCellCleanup) {
        return $cell
    }
    # Pre-1.29 truncated redirected tables: strip ellipsis / registered mojibake.
    $cell = $cell.Replace([string][char]0x2026, '')
    $cell = $cell.Replace(
        ([string][char]0x00E2) + [char]0x20AC + [char]0x00A6, '')
    $cell = $cell.Replace(
        ([string][char]0x00C3) + [char]0x82 + [char]0x00C2 + [char]0x00AE, '')
    $cell = $cell.Replace(([string][char]0x00C2) + [char]0x00AE, '')
    $cell = $cell.Replace([string][char]0x00AE, '')
    $cell = $cell.Replace(([string][char]0x00C2) + [char]0x00AB, '')
    $cell = $cell.Replace([string][char]0x00AB, '')
    return $cell.Trim()
}

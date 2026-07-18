#Requires -Version 5.1
<#
.SYNOPSIS
    Convert winget CLI table text into PSCustomObjects (Plane B fallback).

.DESCRIPTION
    **Safety tier: 1**

    Read-only parser for Windows PowerShell 5.1 and PowerShell 7+.
    Improves on https://gist.github.com/marzme/34fe1a7a003b60847bb26fbff865bf51:
    - Filters pin / upgrades-available footers
    - Column slice by header char offsets (no ConvertFrom-String datetime coercion)
    - Explicit-target section trim
    Prefer Microsoft.WinGet.Client (Plane A) when pwsh is available.

    WGA-006 (winget 1.29+): redirected list uses full column widths — ellipsis /
    mojibake cell strip is OFF by default. Pass -LegacyCellCleanup for older
    App Installer builds that truncates redirected tables.

.NOTES
    Dot-source this file, then pipe winget stdout into Convert-WingetTextToObject.
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

function Convert-WingetTextToObject {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string[]] $WingetRawText,

        [switch] $LegacyCellCleanup
    )

    begin {
        $lines = New-Object 'System.Collections.Generic.List[string]'
        $script:WgaLegacyCellCleanup = [bool]$LegacyCellCleanup
    }

    process {
        foreach ($line in $WingetRawText) {
            if (-not [string]::IsNullOrWhiteSpace($line)) {
                [void]$lines.Add($line)
            }
        }
        if ($PSBoundParameters.ContainsKey('LegacyCellCleanup')) {
            $script:WgaLegacyCellCleanup = [bool]$LegacyCellCleanup
        }
    }

    end {
        if ($lines.Count -eq 0) {
            throw 'No input received.'
        }

        $text = [string[]]$lines.ToArray()

        $explicitIdx = -1
        for ($i = 0; $i -lt $text.Length; $i++) {
            if ($text[$i] -like '*require explicit targeting for upgrade*') {
                $explicitIdx = $i
                break
            }
        }
        if ($explicitIdx -ge 0) {
            if ($explicitIdx -eq 0) {
                throw 'Only explicit-target section found; no package table.'
            }
            $text = $text[0..($explicitIdx - 1)]
        }

        $dashIdx = -1
        for ($i = 0; $i -lt $text.Length; $i++) {
            if ($text[$i] -match '^-+$') {
                $dashIdx = $i
                break
            }
        }
        if ($dashIdx -lt 1) {
            throw "Couldn't find header row."
        }

        $headerRow = $text[$dashIdx - 1]
        $dataRows = @()
        if ($dashIdx + 1 -le $text.Length - 1) {
            $dataRows = $text[($dashIdx + 1)..($text.Length - 1)]
        }

        $dataRows = @(
            $dataRows | Where-Object {
                $_ -notmatch 'upgrades available.*|package\(s\) have pins|require explicit targeting'
            }
        )

        $starts = New-Object 'System.Collections.Generic.List[int]'
        $inWord = $false
        for ($c = 0; $c -lt $headerRow.Length; $c++) {
            $isWs = [char]::IsWhiteSpace($headerRow[$c])
            if (-not $isWs -and -not $inWord) {
                [void]$starts.Add($c)
                $inWord = $true
            }
            elseif ($isWs) {
                $inWord = $false
            }
        }
        if ($starts.Count -lt 2) {
            throw "Couldn't parse column headers from: $headerRow"
        }

        $columnNames = for ($i = 0; $i -lt $starts.Count; $i++) {
            $start = $starts[$i]
            $end = if ($i -lt $starts.Count - 1) { $starts[$i + 1] } else { $headerRow.Length }
            $headerRow.Substring($start, $end - $start).Trim()
        }

        $legacy = [bool]$script:WgaLegacyCellCleanup
        foreach ($row in $dataRows) {
            if ([string]::IsNullOrWhiteSpace($row)) {
                continue
            }
            $props = [ordered]@{}
            for ($i = 0; $i -lt $columnNames.Count; $i++) {
                $next = if ($i -lt $starts.Count - 1) { $starts[$i + 1] } else { -1 }
                $props[$columnNames[$i]] = Get-WgaWingetCell -Row $row -Start $starts[$i] `
                    -NextStart $next -LegacyCellCleanup:$legacy
            }
            [pscustomobject]$props
        }
    }
}

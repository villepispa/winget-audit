#Requires -Version 5.1
Describe 'Plane B CLI parser' {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        $harness = Join-Path $repoRoot 'tests\helpers\Import-WgaTestHarness.ps1'
        if (-not (Test-Path -LiteralPath $harness)) {
            $repoRoot = Split-Path -Parent $PSScriptRoot
            $harness = Join-Path $repoRoot 'tests\helpers\Import-WgaTestHarness.ps1'
        }
        . $harness
    }

    It 'parses a minimal winget list WindowsAppRuntime table' {
        # Prefer WindowsAppRuntime over one-off apps (Halloy) — present on typical Win11 fleets.
        # Fixed-width columns must match header starts (parser slices by header offsets).
        $fixture = @(
            'Name                     Id                               Version Available Source',
            '--------------------------------------------------------------------------------',
            'Windows App Runtime 1.5  Microsoft.WindowsAppRuntime.1.5  1.5.1               winget',
            'Windows App Runtime 1.6  Microsoft.WindowsAppRuntime.1.6  1.6.1               winget'
        )
        $rows = @($fixture | Convert-WingetTextToObject)
        $rows.Count | Should -Be 2
        $rows[0].Id | Should -Be 'Microsoft.WindowsAppRuntime.1.5'
        $rows[0].Version | Should -Be '1.5.1'
        $rows[1].Id | Should -Be 'Microsoft.WindowsAppRuntime.1.6'
    }

    It 'LegacyCellCleanup strips U+2026 ellipsis when enabled' {
        $ellipsis = [char]0x2026
        $row = 'Foo{0}XXXX' -f $ellipsis
        $plain = Get-WgaWingetCell -Row $row -Start 0 -NextStart 4
        $plain | Should -Be ("Foo{0}" -f $ellipsis)
        $legacy = Get-WgaWingetCell -Row $row -Start 0 -NextStart 4 -LegacyCellCleanup
        $legacy | Should -Be 'Foo'
    }

    It 'Resolve-WinGetExe finds winget.exe when App Installer is present' {
        $path = Resolve-WinGetExe
        Test-Path -LiteralPath $path | Should -BeTrue
        (Split-Path -Leaf $path) | Should -Be 'winget.exe'
    }

    It 'winget list WindowsAppRuntime returns parseable rows' {
        $exe = Resolve-WinGetExe
        $lines = @(
            & $exe list WindowsAppRuntime --accept-source-agreements 2>&1 |
                ForEach-Object { "$_" }
        )
        $LASTEXITCODE | Should -Be 0
        $rows = @($lines | Convert-WingetTextToObject)
        $rows.Count | Should -BeGreaterThan 0
        $hit = @(
            $rows | Where-Object {
                $_.Id -like '*WindowsAppRuntime*' -or
                $_.Name -like '*Windows App Runtime*'
            }
        )
        $hit.Count | Should -BeGreaterThan 0
    }
}

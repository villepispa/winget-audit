#Requires -Version 5.1
Describe 'Intune EAC stub size gate' {
    BeforeAll {
        $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
        if (-not (Test-Path -LiteralPath (Join-Path $repoRoot 'deploy\intune'))) {
            $repoRoot = Split-Path -Parent $PSScriptRoot
        }
        $script:stubDir = Join-Path $repoRoot 'deploy\intune'
        $script:gateScript = Join-Path $repoRoot 'scripts\Test-IntuneStubSize.ps1'
        $script:maxBytes = 51200
    }

    It 'deploy/intune contains at least one .ps1 stub' {
        $files = @(Get-ChildItem -LiteralPath $script:stubDir -Filter '*.ps1' -File)
        $files.Count | Should -BeGreaterThan 0
    }

    It 'every deploy/intune/*.ps1 stays within 51200 bytes' {
        $files = @(Get-ChildItem -LiteralPath $script:stubDir -Filter '*.ps1' -File)
        foreach ($f in $files) {
            if ($f.Length -gt $script:maxBytes) {
                throw ("{0} is {1} bytes (max {2})" -f $f.Name, $f.Length, $script:maxBytes)
            }
        }
        $true | Should -BeTrue
    }

    It 'Test-IntuneStubSize.ps1 exits 0 on current stubs' {
        $out = & $script:gateScript -Json 2>&1
        $LASTEXITCODE | Should -Be 0
        $json = $out | Out-String | ConvertFrom-Json
        $json.ok | Should -BeTrue
        $json.data.maxBytes | Should -Be $script:maxBytes
    }
}

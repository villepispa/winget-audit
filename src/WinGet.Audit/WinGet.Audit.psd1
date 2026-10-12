@{
    RootModule        = 'WinGet.Audit.psm1'
    ModuleVersion     = '0.4.0'
    GUID              = 'e7c4b2a1-6d8f-4c3e-9a15-2b7f0e4d8c61'
    Author            = 'Ville Pispa'
    CompanyName       = 'Independent'
    Copyright         = '(c) 2026 Ville Pispa. MIT License.'
    Description       = 'SYSTEM-aware WinGet inventory, detection state, and Intune-thin helpers. Not an updater.'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Resolve-WgaDetectionState'
        'Get-WgaDetectionExitCode'
        'New-WgaDetectionResult'
        'Resolve-WinGetExe'
        'Convert-WingetTextToObject'
        'Invoke-WgaDetectPackage'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('WinGet', 'Intune', 'Inventory', 'Detection', 'PowerShell')
            LicenseUri   = 'https://opensource.org/licenses/MIT'
            ProjectUri   = 'https://github.com/villepispa/winget-audit'
            ReleaseNotes = 'v0.4.0 — src/WinGet.Audit module (Public/Private), DSM-style layout.'
        }
    }
}

@{
    # Product lint settings for WinGet.Audit (scripts/ + deploy/intune/).
    Severity = @('Error', 'Warning')

    # Demo/detect entry points are inventory/read-oriented; ShouldProcess N/A.
    # Workspace files are UTF-8 without BOM.
    ExcludeRules = @(
        'PSUseShouldProcessForStateChangingFunctions',
        'PSUseBOMForUnicodeEncodedFile'
    )
}

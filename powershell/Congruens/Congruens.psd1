@{
    # Module manifest for Congruens
    # A cross-platform CLI experience module

    # Script module file associated with this manifest
    RootModule = 'Congruens.psm1'

    # Version number of this module
    ModuleVersion = '1.0.0'

    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'

    # Author of this module
    Author = 'Congruens'

    # Description of the functionality provided by this module
    Description = 'A shared cross-platform CLI experience - same muscle-memory, same look'

    # Minimum version of PowerShell required by this module
    PowerShellVersion = '7.0'

    # Functions to export from this module
    FunctionsToExport = @(
        # Core commands
        'New-DirectoryAndEnter',
        'Open-Path',
        'Get-CommandPath',
        'Invoke-PathCommand',
        'Show-CongruensManual',
        'Show-Motd',
        
        # Tool wrappers
        'Invoke-Eza',

        # Aliases (exported as functions)
        'mkcd',
        'which',
        'll',
        'cgrman',
        'motd'
    )

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Aliases to export from this module
    AliasesToExport = @(
        'open',
        'path'
    )

    # Private data to pass to the module
    PrivateData = @{
        PSData = @{
            # Tags applied to this module for discoverability
            Tags = @('CLI', 'CrossPlatform', 'Productivity')

            # Project URI
            ProjectUri = 'https://github.com/yourusername/congruens'
        }
    }
}

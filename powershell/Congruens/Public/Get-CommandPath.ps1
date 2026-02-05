<#
.SYNOPSIS
    Cross-platform 'which' command.

.DESCRIPTION
    Finds the location of a command, working with native commands,
    PowerShell aliases, functions, and cmdlets.
#>

function Get-CommandPath {
    <#
    .SYNOPSIS
        Finds the location of a command.
    
    .DESCRIPTION
        Returns the full path or definition of a command. Works with:
        - Native executables (returns file path)
        - PowerShell aliases (shows what they point to)
        - PowerShell functions (shows definition)
        - PowerShell cmdlets (shows module and name)
    
    .PARAMETER Name
        The name of the command to find.
    
    .PARAMETER All
        If specified, shows all matching commands (not just the first).
    
    .EXAMPLE
        Get-CommandPath git
        
        Returns: C:\Program Files\Git\cmd\git.exe
    
    .EXAMPLE
        which ls
        
        Shows what 'ls' resolves to (alias on Windows, native on Unix).
    
    .EXAMPLE
        which -All python
        
        Shows all python executables in PATH.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter()]
        [switch]$All
    )

    $commands = Get-Command $Name -All:$All -ErrorAction SilentlyContinue

    if (-not $commands) {
        Write-Error "Command not found: $Name"
        return
    }

    foreach ($cmd in $commands) {
        $result = [PSCustomObject]@{
            Name       = $cmd.Name
            Type       = $cmd.CommandType.ToString()
            Source     = $null
            Definition = $null
        }

        switch ($cmd.CommandType) {
            'Application' {
                $result.Source = $cmd.Source
                $result.Definition = $cmd.Source
            }
            'Alias' {
                $result.Source = $cmd.Definition
                $result.Definition = "Alias -> $($cmd.Definition)"
            }
            'Function' {
                $result.Source = 'Function'
                $result.Definition = $cmd.Definition
            }
            'Cmdlet' {
                $result.Source = $cmd.ModuleName
                $result.Definition = "$($cmd.ModuleName)\$($cmd.Name)"
            }
            'ExternalScript' {
                $result.Source = $cmd.Source
                $result.Definition = $cmd.Source
            }
            default {
                $result.Definition = $cmd.Definition
            }
        }

        # For simple output, just return the source/path
        if ($cmd.CommandType -eq 'Application' -or $cmd.CommandType -eq 'ExternalScript') {
            Write-Output $result.Source
        }
        else {
            Write-Output $result.Definition
        }
    }
}

# Alias for convenience
function which {
    <#
    .SYNOPSIS
        Alias for Get-CommandPath.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Name,

        [Parameter()]
        [Alias('a')]
        [switch]$All
    )

    Get-CommandPath -Name $Name -All:$All
}

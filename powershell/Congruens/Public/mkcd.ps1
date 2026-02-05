<#
.SYNOPSIS
    Create a directory and change into it.

.DESCRIPTION
    Creates a new directory (including parent directories if needed) and
    immediately changes the current location to that directory.
#>

function New-DirectoryAndEnter {
    <#
    .SYNOPSIS
        Creates a directory and changes into it.
    
    .DESCRIPTION
        Creates a new directory (and any necessary parent directories) and
        immediately sets the current location to that directory.
    
    .PARAMETER Path
        The path of the directory to create and enter.
    
    .EXAMPLE
        New-DirectoryAndEnter -Path 'my-project'
        
        Creates 'my-project' in the current directory and cd's into it.
    
    .EXAMPLE
        mkcd projects/new-app
        
        Creates 'projects/new-app' and cd's into it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    # Expand path (handle ~ and environment variables)
    $expandedPath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path)

    try {
        # Create directory if it doesn't exist
        if (-not (Test-Path $expandedPath -PathType Container)) {
            $null = New-Item -Path $expandedPath -ItemType Directory -Force -ErrorAction Stop
            Write-Verbose "Created directory: $expandedPath"
        }

        # Change to the directory
        Set-Location -Path $expandedPath -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to create or enter directory '$Path': $_"
    }
}

# Alias for convenience
function mkcd {
    <#
    .SYNOPSIS
        Alias for New-DirectoryAndEnter.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )

    New-DirectoryAndEnter -Path $Path
}

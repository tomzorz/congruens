<#
.SYNOPSIS
    Congruens PATH environment variable management.

.DESCRIPTION
    Provides commands for viewing and manipulating the PATH environment variable.
    Supports show, addsession, addpermanent, and remove operations.
#>

function Invoke-CongruensPathCommand {
    <#
    .SYNOPSIS
        Manages the PATH environment variable.
    
    .DESCRIPTION
        A multi-purpose command for PATH manipulation:
        - show: Display PATH entries, one per line
        - addsession: Add a directory to the current session PATH
        - addpermanent: Add a directory to PATH permanently
        - remove: Remove a directory from session PATH
    
    .PARAMETER Action
        The action to perform: show, addsession, addpermanent, or remove.
    
    .PARAMETER Directory
        The directory to add or remove (required for addsession/addpermanent/remove).
    
    .EXAMPLE
        cgrpath show
        
        Displays all PATH entries, one per line.
    
    .EXAMPLE
        cgrpath addsession C:\tools\bin
        
        Adds C:\tools\bin to the current session's PATH.
    
    .EXAMPLE
        cgrpath addpermanent C:\tools\bin
        
        Permanently adds C:\tools\bin to the user's PATH.
    
    .EXAMPLE
        cgrpath remove C:\tools\bin
        
        Removes C:\tools\bin from the current session's PATH.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('show', 'addsession', 'addpermanent', 'remove')]
        [string]$Action = 'show',

        [Parameter(Position = 1)]
        [string]$Directory
    )

    # Get path separator for current platform
    $pathSep = [IO.Path]::PathSeparator

    switch ($Action) {
        'show' {
            # Display PATH entries, one per line, with index
            $paths = $env:PATH -split [regex]::Escape($pathSep)
            $index = 0
            foreach ($p in $paths) {
                if ($p) {
                    $exists = Test-Path $p -PathType Container
                    $status = if ($exists) { ' ' } else { '!' }
                    Write-Output ("{0,3} {1} {2}" -f $index, $status, $p)
                    $index++
                }
            }
        }

        'addsession' {
            if (-not $Directory) {
                Write-Error "Directory required for 'addsession' action"
                return
            }

            $expandedDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Directory)
            
            if (-not (Test-Path $expandedDir -PathType Container)) {
                Write-Warning "Directory does not exist: $expandedDir"
            }

            $paths = $env:PATH -split [regex]::Escape($pathSep)
            if ($expandedDir -in $paths) {
                Write-Verbose "Directory already in PATH: $expandedDir"
                return
            }

            $env:PATH = $expandedDir + $pathSep + $env:PATH
            Write-Output "Added to session PATH: $expandedDir"
        }

        'addpermanent' {
            if (-not $Directory) {
                Write-Error "Directory required for 'addpermanent' action"
                return
            }

            $expandedDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Directory)

            if (-not (Test-Path $expandedDir -PathType Container)) {
                Write-Warning "Directory does not exist: $expandedDir"
            }

            if (Test-IsWindows) {
                # Windows: Add to user environment variable
                $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
                $paths = $currentPath -split ';'
                
                if ($expandedDir -in $paths) {
                    Write-Output "Directory already in persistent PATH: $expandedDir"
                    return
                }

                $newPath = $expandedDir + ';' + $currentPath
                [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
                
                # Also add to current session
                $env:PATH = $expandedDir + ';' + $env:PATH
                
                Write-Output "Persisted to user PATH: $expandedDir"
                Write-Output "(Changes will apply to new terminal sessions)"
            }
            else {
                # Unix: Suggest adding to shell profile
                $profilePath = if (Test-IsMac) {
                    "~/.zshrc or ~/.bash_profile"
                }
                else {
                    "~/.bashrc or ~/.profile"
                }

                Write-Output "To persist on Unix, add this to $profilePath :"
                Write-Output ""
                Write-Output "export PATH=`"$expandedDir`:`$PATH`""
                
                # Still add to current session
                $env:PATH = $expandedDir + ':' + $env:PATH
                Write-Output ""
                Write-Output "Added to current session PATH: $expandedDir"
            }
        }

        'remove' {
            if (-not $Directory) {
                Write-Error "Directory required for 'remove' action"
                return
            }

            $expandedDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Directory)
            $paths = $env:PATH -split [regex]::Escape($pathSep)
            
            # Filter out the directory (case-insensitive on Windows)
            $newPaths = if (Test-IsWindows) {
                $paths | Where-Object { $_ -and ($_.TrimEnd('\') -ne $expandedDir.TrimEnd('\')) }
            }
            else {
                $paths | Where-Object { $_ -and ($_.TrimEnd('/') -ne $expandedDir.TrimEnd('/')) }
            }

            if ($newPaths.Count -eq $paths.Count) {
                Write-Warning "Directory not found in PATH: $expandedDir"
                return
            }

            $env:PATH = $newPaths -join $pathSep
            Write-Output "Removed from PATH: $expandedDir"
        }
    }
}

function cgrpath {
    <#
    .SYNOPSIS
        Alias for Invoke-CongruensPathCommand.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('show', 'addsession', 'addpermanent', 'remove')]
        [string]$Action = 'show',

        [Parameter(Position = 1)]
        [string]$Directory
    )
    Invoke-CongruensPathCommand @PSBoundParameters
}

<#
.SYNOPSIS
    Cross-platform file explorer opener.

.DESCRIPTION
    Opens a path in the system's default file explorer.
    Works on Windows (explorer), macOS (open), and Linux (xdg-open).
#>

function Open-Path {
    <#
    .SYNOPSIS
        Opens a path in the system's file explorer.
    
    .DESCRIPTION
        Opens the specified path (or current directory if not specified) in
        the system's default file explorer application.
        
        - Windows: Uses explorer.exe
        - macOS: Uses open
        - Linux: Uses xdg-open
    
    .PARAMETER Path
        The path to open. Defaults to current directory.
    
    .EXAMPLE
        Open-Path
        
        Opens current directory in file explorer.
    
    .EXAMPLE
        Open-Path ~/Documents
        
        Opens Documents folder in file explorer.
    
    .EXAMPLE
        open .
        
        Opens current directory (using alias).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Path = '.'
    )

    # Expand and resolve path
    $resolvedPath = Resolve-Path -Path $Path -ErrorAction SilentlyContinue
    if (-not $resolvedPath) {
        Write-Error "Path not found: $Path"
        return
    }

    $targetPath = $resolvedPath.Path

    try {
        if (Test-IsWindows) {
            # Windows: use explorer
            Start-Process explorer.exe -ArgumentList $targetPath
        }
        elseif (Test-IsMac) {
            # macOS: use open
            Start-Process 'open' -ArgumentList $targetPath
        }
        elseif (Test-IsLinux) {
            # Linux: use xdg-open
            Start-Process 'xdg-open' -ArgumentList $targetPath
        }
        else {
            Write-Error "Unsupported platform"
        }
    }
    catch {
        Write-Error "Failed to open '$targetPath': $_"
    }
}

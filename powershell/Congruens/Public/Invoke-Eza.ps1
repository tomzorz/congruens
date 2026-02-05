<#
.SYNOPSIS
    Enhanced directory listing using eza.

.DESCRIPTION
    Wrapper for eza (modern replacement for ls) with long format by default.
    Provides the 'll' alias familiar from Unix systems.
#>

function Invoke-Eza {
    <#
    .SYNOPSIS
        Lists directory contents using eza in long format.
    
    .DESCRIPTION
        Calls eza with the -la (long and all) flag and passes through any additional arguments.
        Requires eza to be installed.
    
    .PARAMETER Path
        The path to list. Defaults to current directory.
    
    .EXAMPLE
        Invoke-Eza
        
        Lists current directory in long format.
    
    .EXAMPLE
        ll -T
        
        Lists all files in current directory with tree view.
    
    .EXAMPLE
        ll C:\Projects
        
        Lists the specified directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    if (-not (Get-Command eza -ErrorAction SilentlyContinue)) {
        Write-Error "eza is not installed. Install it via 'winget install eza-community.eza' or 'choco install eza'."
        return
    }

    # Filter out null/empty arguments to avoid passing empty strings to eza
    $cleanArgs = @($Arguments | Where-Object { $_ -ne $null -and $_ -ne '' })
    
    if ($cleanArgs.Count -gt 0) {
        eza -la @cleanArgs
    } else {
        eza -la
    }
}

# Alias for convenience
function ll {
    <#
    .SYNOPSIS
        Alias for Invoke-Eza (eza -la).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    if ($Arguments -and $Arguments.Count -gt 0) {
        Invoke-Eza -Arguments $Arguments
    } else {
        Invoke-Eza
    }
}

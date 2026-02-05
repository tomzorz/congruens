<#
.SYNOPSIS
    Platform detection helper functions.

.DESCRIPTION
    Provides cross-platform detection functions for Windows, macOS, and Linux.
    These are private helper functions used by other module commands.
#>

function Test-IsWindows {
    <#
    .SYNOPSIS
        Returns $true if running on Windows.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return $IsWindows
    }
    # PowerShell 5.1 only runs on Windows
    return $true
}

function Test-IsMac {
    <#
    .SYNOPSIS
        Returns $true if running on macOS.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return $IsMacOS
    }
    return $false
}

function Test-IsLinux {
    <#
    .SYNOPSIS
        Returns $true if running on Linux.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($PSVersionTable.PSVersion.Major -ge 6) {
        return $IsLinux
    }
    return $false
}

function Get-Platform {
    <#
    .SYNOPSIS
        Returns the current platform name.
    
    .OUTPUTS
        String: 'windows', 'macos', or 'linux'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if (Test-IsWindows) { return 'windows' }
    if (Test-IsMac) { return 'macos' }
    if (Test-IsLinux) { return 'linux' }
    return 'unknown'
}

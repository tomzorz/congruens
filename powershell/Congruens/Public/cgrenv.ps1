<#
.SYNOPSIS
    Congruens environment variable management.

.DESCRIPTION
    Provides commands for viewing and manipulating environment variables.
    Supports show, addsession, and addpermanent operations.
#>

function Invoke-CongruensEnvCommand {
    <#
    .SYNOPSIS
        Manages environment variables.
    
    .DESCRIPTION
        A multi-purpose command for environment variable management:
        - show: Display all environment variables, or a specific one by name
        - addsession: Set an environment variable for the current session
        - addpermanent: Set an environment variable permanently (user scope)
    
    .PARAMETER Action
        The action to perform: show, addsession, or addpermanent.
    
    .PARAMETER Name
        The environment variable name (optional for show, required for addsession/addpermanent).
    
    .PARAMETER Value
        The value to set (required for addsession/addpermanent).
    
    .EXAMPLE
        cgrenv show
        
        Displays all environment variables sorted by name.
    
    .EXAMPLE
        cgrenv show JAVA_HOME
        
        Displays the value of the JAVA_HOME environment variable.
    
    .EXAMPLE
        cgrenv addsession MY_VAR "some value"
        
        Sets MY_VAR to "some value" for the current session only.
    
    .EXAMPLE
        cgrenv addpermanent MY_VAR "some value"
        
        Sets MY_VAR to "some value" permanently (user scope on Windows,
        suggests shell profile on Unix).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('show', 'addsession', 'addpermanent')]
        [string]$Action = 'show',

        [Parameter(Position = 1)]
        [string]$Name,

        [Parameter(Position = 2)]
        [string]$Value
    )

    switch ($Action) {
        'show' {
            if ($Name) {
                # Show a specific environment variable
                $val = [Environment]::GetEnvironmentVariable($Name)
                if ($null -eq $val) {
                    Write-Warning "Environment variable not found: $Name"
                }
                else {
                    Write-Output "$Name=$val"
                }
            }
            else {
                # Show all environment variables, sorted by name
                $vars = [Environment]::GetEnvironmentVariables()
                $sorted = $vars.GetEnumerator() | Sort-Object Name
                foreach ($entry in $sorted) {
                    Write-Output ("{0}={1}" -f $entry.Name, $entry.Value)
                }
            }
        }

        'addsession' {
            if (-not $Name) {
                Write-Error "Variable name required for 'addsession' action"
                return
            }
            if (-not $PSBoundParameters.ContainsKey('Value')) {
                Write-Error "Value required for 'addsession' action. Usage: cgrenv addsession <Name> <Value>"
                return
            }

            [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
            Write-Output "Set session variable: $Name=$Value"
        }

        'addpermanent' {
            if (-not $Name) {
                Write-Error "Variable name required for 'addpermanent' action"
                return
            }
            if (-not $PSBoundParameters.ContainsKey('Value')) {
                Write-Error "Value required for 'addpermanent' action. Usage: cgrenv addpermanent <Name> <Value>"
                return
            }

            if (Test-IsWindows) {
                # Windows: Set in user environment
                [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
                
                # Also set in current session
                [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')

                Write-Output "Persisted user variable: $Name=$Value"
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
                Write-Output "export $Name=`"$Value`""

                # Still set in current session
                [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
                Write-Output ""
                Write-Output "Set in current session: $Name=$Value"
            }
        }
    }
}

function cgrenv {
    <#
    .SYNOPSIS
        Alias for Invoke-CongruensEnvCommand.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('show', 'addsession', 'addpermanent')]
        [string]$Action = 'show',

        [Parameter(Position = 1)]
        [string]$Name,

        [Parameter(Position = 2)]
        [string]$Value
    )
    Invoke-CongruensEnvCommand @PSBoundParameters
}

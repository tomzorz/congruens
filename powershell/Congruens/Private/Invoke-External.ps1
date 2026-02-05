<#
.SYNOPSIS
    Safe native command execution helper.

.DESCRIPTION
    Provides a wrapper for executing external/native commands with proper
    error handling and cross-platform support.
#>

function Invoke-External {
    <#
    .SYNOPSIS
        Executes an external command with error handling.
    
    .DESCRIPTION
        Runs a native command and captures output. Provides consistent
        error handling across platforms.
    
    .PARAMETER Command
        The command to execute.
    
    .PARAMETER Arguments
        Arguments to pass to the command.
    
    .PARAMETER WorkingDirectory
        Optional working directory for command execution.
    
    .PARAMETER PassThru
        If specified, returns an object with exit code, stdout, and stderr.
    
    .EXAMPLE
        Invoke-External -Command 'git' -Arguments @('status')
    
    .EXAMPLE
        Invoke-External -Command 'npm' -Arguments @('install') -WorkingDirectory 'C:\Projects\MyApp'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Command,

        [Parameter()]
        [string[]]$Arguments = @(),

        [Parameter()]
        [string]$WorkingDirectory,

        [Parameter()]
        [switch]$PassThru
    )

    # Resolve command path
    $cmdPath = Get-Command $Command -ErrorAction SilentlyContinue
    if (-not $cmdPath) {
        if ($PassThru) {
            return [PSCustomObject]@{
                ExitCode = 1
                StdOut   = ''
                StdErr   = "Command not found: $Command"
                Success  = $false
            }
        }
        Write-Error "Command not found: $Command"
        return
    }

    # Build process start info
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $cmdPath.Source
    $psi.RedirectStandardOutput = $PassThru
    $psi.RedirectStandardError = $PassThru
    $psi.UseShellExecute = -not $PassThru
    $psi.CreateNoWindow = $PassThru

    if ($WorkingDirectory -and (Test-Path $WorkingDirectory -PathType Container)) {
        $psi.WorkingDirectory = $WorkingDirectory
    }

    foreach ($arg in $Arguments) {
        $psi.ArgumentList.Add($arg)
    }

    try {
        if ($PassThru) {
            $process = [System.Diagnostics.Process]::Start($psi)
            $stdout = $process.StandardOutput.ReadToEnd()
            $stderr = $process.StandardError.ReadToEnd()
            $process.WaitForExit()

            return [PSCustomObject]@{
                ExitCode = $process.ExitCode
                StdOut   = $stdout
                StdErr   = $stderr
                Success  = $process.ExitCode -eq 0
            }
        }
        else {
            # Direct execution with output to console
            & $cmdPath.Source @Arguments
            return $LASTEXITCODE -eq 0
        }
    }
    catch {
        if ($PassThru) {
            return [PSCustomObject]@{
                ExitCode = 1
                StdOut   = ''
                StdErr   = $_.Exception.Message
                Success  = $false
            }
        }
        Write-Error $_.Exception.Message
        return $false
    }
}

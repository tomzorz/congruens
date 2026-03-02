<#
.SYNOPSIS
    Install development environments from devenvs/*.json definitions.

.DESCRIPTION
    Reads devenv definitions from the devenvs/ directory and runs the
    platform-appropriate install script. Persists environment variables
    to the user's shell configuration.
#>

function Install-CongruensDevEnv {
    <#
    .SYNOPSIS
        Install a development environment by name.

    .DESCRIPTION
        Reads devenvs/<name>.json, checks if already installed via the verify
        command, runs the platform-specific install script, and persists any
        required environment variables.

    .PARAMETER Name
        The devenv to install (matches a JSON filename in devenvs/).

    .PARAMETER Force
        Install even if the verify command succeeds (reinstall).

    .PARAMETER DryRun
        Show what would be done without making changes.

    .PARAMETER List
        List available devenvs and their install status.

    .EXAMPLE
        cgrinstall dotnet

        Installs the .NET SDK using the platform-appropriate method.

    .EXAMPLE
        cgrinstall -List

        Shows all available devenvs and whether they're already installed.

    .EXAMPLE
        cgrinstall python -Force

        Reinstalls Python/uv even if already present.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [switch]$Force,
        [switch]$DryRun,
        [switch]$List
    )

    $congruensRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $devenvPath = Join-Path $congruensRoot "devenvs"
    $platform = Get-Platform

    if (-not (Test-Path $devenvPath)) {
        Write-Error "Devenvs directory not found at $devenvPath"
        return
    }

    # List mode: show all devenvs and their status
    if ($List) {
        Show-DevEnvList -DevEnvPath $devenvPath -Platform $platform
        return
    }

    if (-not $Name) {
        Write-Host ""
        Write-Host "  Usage: cgrinstall <name> [-Force] [-DryRun]" -ForegroundColor Yellow
        Write-Host "         cgrinstall -List" -ForegroundColor Yellow
        Write-Host ""
        Show-DevEnvList -DevEnvPath $devenvPath -Platform $platform
        return
    }

    $devenvFile = Join-Path $devenvPath "$Name.json"
    if (-not (Test-Path $devenvFile)) {
        Write-Error "No devenv definition found: $devenvFile"
        Write-Host ""
        Write-Host "  Available devenvs:" -ForegroundColor Yellow
        Get-ChildItem -Path $devenvPath -Filter "*.json" | ForEach-Object {
            Write-Host "    $([System.IO.Path]::GetFileNameWithoutExtension($_.Name))" -ForegroundColor Gray
        }
        return
    }

    $devenv = Get-Content $devenvFile -Raw | ConvertFrom-Json
    Write-Host ""
    Write-Host "  Installing: $($devenv.name)" -ForegroundColor Cyan
    Write-Host "  $($devenv.description)" -ForegroundColor Gray
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray

    # Check if already installed
    if (-not $Force -and $devenv.verify) {
        $verifyBin = ($devenv.verify -split ' ')[0]
        if (Get-Command $verifyBin -ErrorAction SilentlyContinue) {
            Write-Host ""
            Write-Host "  Already installed" -ForegroundColor Green -NoNewline
            Write-Host " (use -Force to reinstall)" -ForegroundColor DarkGray
            Write-Host ""
            return
        }
    }

    # Get platform-specific install config
    $platformInstall = $devenv.install.$platform
    if (-not $platformInstall -or -not $platformInstall.script) {
        Write-Error "No install script defined for platform: $platform"
        return
    }

    $scripts = @($platformInstall.script)

    # Run install scripts
    Write-Host ""
    $stepNum = 0
    $totalSteps = $scripts.Count
    $failed = $false

    foreach ($cmd in $scripts) {
        $stepNum++
        Write-Host "  [$stepNum/$totalSteps] " -ForegroundColor DarkGray -NoNewline
        Write-Host "$cmd" -ForegroundColor White

        if ($DryRun) {
            Write-Host "           (dry run, skipped)" -ForegroundColor DarkGray
            continue
        }

        $success = Invoke-DevEnvCommand -Command $cmd -Platform $platform
        if (-not $success) {
            Write-Host "           FAILED" -ForegroundColor Red
            $failed = $true
            break
        }
        Write-Host "           OK" -ForegroundColor Green
    }

    if ($failed -and -not $DryRun) {
        Write-Host ""
        Write-Host "  Installation failed. Check the output above for details." -ForegroundColor Red
        Write-Host ""
        return
    }

    # Persist environment variables
    $platformEnv = $devenv.env.$platform
    if ($platformEnv) {
        $envVars = $platformEnv | Get-Member -MemberType NoteProperty
        if ($envVars.Count -gt 0) {
            Write-Host ""
            Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
            Write-Host "  Setting environment variables:" -ForegroundColor DarkGray
            Write-Host ""

            foreach ($prop in $envVars) {
                $varName = $prop.Name
                $varValue = $platformEnv.$varName
                if (-not $varValue) { continue }

                Write-Host "  $varName" -ForegroundColor Yellow -NoNewline
                Write-Host " = " -ForegroundColor DarkGray -NoNewline
                Write-Host "$varValue" -ForegroundColor White

                if (-not $DryRun) {
                    Set-DevEnvVar -Name $varName -Value $varValue -Platform $platform
                }
            }
        }
    }

    Write-Host ""
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray

    if ($DryRun) {
        Write-Host "  Dry run complete. Run without -DryRun to apply changes." -ForegroundColor Yellow
    } else {
        Write-Host "  Installed: $($devenv.name)" -ForegroundColor Green
        if ($devenv.verify) {
            Write-Host "  Verify:    $($devenv.verify)" -ForegroundColor DarkGray
        }
        Write-Host ""
        Write-Host "  Restart your shell for environment changes to take effect." -ForegroundColor Yellow
    }
    Write-Host ""
}

# --- Private: show list of available devenvs ---

function Show-DevEnvList {
    param(
        [string]$DevEnvPath,
        [string]$Platform
    )

    $files = Get-ChildItem -Path $DevEnvPath -Filter "*.json" | Sort-Object Name

    if ($files.Count -eq 0) {
        Write-Host "  No devenv definitions found." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "  Available development environments:" -ForegroundColor Cyan
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    foreach ($file in $files) {
        try {
            $devenv = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $name = $devenv.name
            $desc = $devenv.description

            # Check install status
            $status = "not installed"
            $statusColor = "DarkGray"
            if ($devenv.verify) {
                $verifyBin = ($devenv.verify -split ' ')[0]
                if (Get-Command $verifyBin -ErrorAction SilentlyContinue) {
                    $status = "installed"
                    $statusColor = "Green"
                }
            }

            $padding = ' ' * [Math]::Max(1, 12 - $name.Length)
            Write-Host "  $name" -ForegroundColor Yellow -NoNewline
            Write-Host "$padding$desc" -ForegroundColor Gray -NoNewline
            Write-Host "  [$status]" -ForegroundColor $statusColor
        }
        catch {
            Write-Warning "  Failed to parse $($file.Name): $_"
        }
    }

    Write-Host ""
}

# --- Private: execute a single install command ---

function Invoke-DevEnvCommand {
    param(
        [string]$Command,
        [string]$Platform
    )

    try {
        if ($Platform -eq 'windows') {
            # On Windows, the devenv scripts are package manager commands
            # (winget, choco, etc.) that run natively in PowerShell
            Invoke-Expression $Command
            return $LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE
        }
        else {
            # On macOS/Linux, shell out to bash for the install commands
            $result = bash -c $Command 2>&1
            $result | ForEach-Object { Write-Host "           $_" -ForegroundColor DarkGray }
            return $LASTEXITCODE -eq 0
        }
    }
    catch {
        Write-Host "           Error: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# --- Private: persist an environment variable ---

function Set-DevEnvVar {
    param(
        [string]$Name,
        [string]$Value,
        [string]$Platform
    )

    if ($Platform -eq 'windows') {
        # On Windows, use the .NET API to set user-level env vars
        $current = [Environment]::GetEnvironmentVariable($Name, 'User')
        if ($current -eq $Value) { return }

        if ($Name -eq 'PATH') {
            # For PATH, append to existing rather than replacing
            $currentPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
            # Expand variables in the value for comparison
            $expandedValue = [Environment]::ExpandEnvironmentVariables($Value)
            if ($currentPath -and $currentPath.Split(';') -contains $expandedValue) { return }
            $newPath = if ($currentPath) { "$currentPath;$Value" } else { $Value }
            [Environment]::SetEnvironmentVariable('PATH', $newPath, 'User')
        }
        else {
            [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
        }
        # Also set for the current session
        [Environment]::SetEnvironmentVariable($Name, $Value, 'Process')
    }
    else {
        # On macOS/Linux, write to shell rc file (before the exec pwsh block)
        Set-DevEnvShellVar -Name $Name -Value $Value
    }
}

# --- Private: write env var to shell rc file on macOS/Linux ---

function Set-DevEnvShellVar {
    param(
        [string]$Name,
        [string]$Value
    )

    # Determine which rc file to use
    $shellRc = if ($env:SHELL -and $env:SHELL -like '*/zsh') {
        Join-Path $HOME ".zshrc"
    } else {
        Join-Path $HOME ".bashrc"
    }

    # PATH additions are special: we need to export as-is (the value contains $PATH)
    $exportLine = "export ${Name}=`"${Value}`""

    if (-not (Test-Path $shellRc)) {
        # Create the rc file if it doesn't exist
        Set-Content -Path $shellRc -Value ""
    }

    $rcContent = Get-Content $shellRc -Raw

    # Check if already set with this exact value
    if ($rcContent -and $rcContent.Contains($exportLine)) { return }

    # Check if the var is already set with a different value, update it
    if ($rcContent -and $rcContent -match "(?m)^export ${Name}=") {
        # Replace existing line
        $escapedName = [regex]::Escape($Name)
        $rcContent = $rcContent -replace "(?m)^export ${escapedName}=.*$", $exportLine
        Set-Content -Path $shellRc -Value $rcContent -NoNewline
        return
    }

    # Insert before the PowerShell auto-launch block if present,
    # because `exec pwsh` replaces the shell and anything after it never runs
    $commentLine = "# $Name (added by congruens devenv installer)"
    $insertBlock = "`n${commentLine}`n${exportLine}"

    if ($rcContent -and $rcContent.Contains("Congruens: Auto-launch PowerShell")) {
        $rcContent = $rcContent -replace "(?m)(# Congruens: Auto-launch PowerShell)", "${insertBlock}`n`$1"
        Set-Content -Path $shellRc -Value $rcContent -NoNewline
    }
    else {
        Add-Content -Path $shellRc -Value "`n${commentLine}"
        Add-Content -Path $shellRc -Value $exportLine
    }
}

# --- Wrapper function ---

function cgrinstall {
    <#
    .SYNOPSIS
        Install a development environment (dotnet, python, node, etc.)
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [switch]$Force,
        [switch]$DryRun,
        [switch]$List
    )

    Install-CongruensDevEnv @PSBoundParameters
}

# --- Tab completion for the Name parameter ---

$_cgrinstallCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $congruensRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $devenvPath = Join-Path $congruensRoot "devenvs"

    if (Test-Path $devenvPath) {
        Get-ChildItem -Path $devenvPath -Filter "*.json" |
            ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_.Name) } |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object {
                [System.Management.Automation.CompletionResult]::new(
                    $_,
                    $_,
                    'ParameterValue',
                    $_
                )
            }
    }
}

Register-ArgumentCompleter -CommandName 'Install-CongruensDevEnv' -ParameterName 'Name' -ScriptBlock $_cgrinstallCompleter
Register-ArgumentCompleter -CommandName 'cgrinstall' -ParameterName 'Name' -ScriptBlock $_cgrinstallCompleter

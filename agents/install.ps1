<#
.SYNOPSIS
    Install agent configurations for AI coding assistants.

.DESCRIPTION
    - Sets OPENCODE_CONFIG_DIR env var for OpenCode (no symlinks needed)
    - Creates symbolic links for Claude Code and Agent Skills standard

.PARAMETER DryRun
    Show what would be done without making changes

.EXAMPLE
    .\install.ps1
    
.EXAMPLE
    .\install.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

# Configuration
# Resolve repo root from this script's location (agents/ -> repo root)
$DotfilesDir = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Split-Path -Parent $PSScriptRoot }
$AgentsDir = Join-Path $DotfilesDir 'agents'
$ConfigDir = Join-Path $AgentsDir 'config'

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] " -ForegroundColor Blue -NoNewline
    Write-Host $Message
}

function Write-Success {
    param([string]$Message)
    Write-Host "[OK] " -ForegroundColor Green -NoNewline
    Write-Host $Message
}

function Write-Warn {
    param([string]$Message)
    Write-Host "[WARN] " -ForegroundColor Yellow -NoNewline
    Write-Host $Message
}

function Write-Err {
    param([string]$Message)
    Write-Host "[ERROR] " -ForegroundColor Red -NoNewline
    Write-Host $Message
}

function New-SymbolicLinkSafe {
    param(
        [string]$Source,
        [string]$Target
    )

    $TargetDir = Split-Path -Parent $Target

    # Create parent directory if needed
    if (-not (Test-Path $TargetDir)) {
        if ($DryRun) {
            Write-Info "Would create directory: $TargetDir"
        } else {
            New-Item -ItemType Directory -Path $TargetDir -Force | Out-Null
            Write-Info "Created directory: $TargetDir"
        }
    }

    # Handle existing target
    if (Test-Path $Target) {
        $item = Get-Item $Target -Force
        
        # Check if it's already the correct symlink
        if ($item.LinkType -eq 'SymbolicLink') {
            $existingTarget = $item.Target
            if ($existingTarget -eq $Source) {
                Write-Success "Already linked: $Target -> $Source"
                return $true
            }
        }

        # Remove and re-create to keep things idempotent
        if ($DryRun) {
            Write-Info "Would replace existing: $Target"
        } else {
            Remove-Item -Path $Target -Recurse -Force
            Write-Warn "Replaced existing: $Target"
        }
    }

    # Create symlink
    if ($DryRun) {
        Write-Info "Would link: $Target -> $Source"
    } else {
        try {
            New-Item -ItemType SymbolicLink -Path $Target -Target $Source -Force | Out-Null
            Write-Success "Linked: $Target -> $Source"
        } catch {
            Write-Err "Failed to create symlink. Try running as Administrator."
            Write-Err $_.Exception.Message
            return $false
        }
    }
    return $true
}

function Set-EnvVar {
    param(
        [string]$Name,
        [string]$Value
    )

    $current = [Environment]::GetEnvironmentVariable($Name, 'User')
    if ($current -eq $Value) {
        Write-Success "Already set: $Name"
        return
    }

    if ($DryRun) {
        Write-Info "Would set user env var: $Name = $Value"
    } else {
        [Environment]::SetEnvironmentVariable($Name, $Value, 'User')
        $env:OPENCODE_CONFIG_DIR = $Value
        Write-Success "Set user env var: $Name = $Value"
    }
}

# Main installation
function Install-AgentConfigs {
    Write-Host ""
    Write-Host "Agent Configuration Installer"
    Write-Host "=============================="
    Write-Host ""

    if ($DryRun) {
        Write-Info "Dry run mode - no changes will be made"
        Write-Host ""
    }

    # Check source exists
    if (-not (Test-Path $ConfigDir)) {
        Write-Err "Config directory not found: $ConfigDir"
        exit 1
    }

    Write-Info "Source: $ConfigDir"
    Write-Host ""

    # OpenCode: set OPENCODE_CONFIG_DIR env var (no symlinks needed)
    Write-Host "OpenCode:"
    Set-EnvVar -Name 'OPENCODE_CONFIG_DIR' -Value $ConfigDir
    Write-Host ""

    # Claude Code symlinks
    Write-Host "Claude Code:"
    New-SymbolicLinkSafe -Source (Join-Path $ConfigDir 'skills') -Target (Join-Path $HOME '.claude\skills') | Out-Null
    New-SymbolicLinkSafe -Source (Join-Path $ConfigDir 'agents') -Target (Join-Path $HOME '.claude\agents') | Out-Null
    New-SymbolicLinkSafe -Source (Join-Path $ConfigDir 'claude-settings.json') -Target (Join-Path $HOME '.claude\settings.json') | Out-Null
    $agentsMd = Join-Path $DotfilesDir 'AGENTS.md'
    if (Test-Path $agentsMd) {
        New-SymbolicLinkSafe -Source $agentsMd -Target (Join-Path $HOME '.claude\CLAUDE.md') | Out-Null
    }
    Write-Host ""

    # Agent Skills standard symlinks
    Write-Host "Agent Skills Standard:"
    New-SymbolicLinkSafe -Source (Join-Path $ConfigDir 'skills') -Target (Join-Path $HOME '.agents\skills') | Out-Null
    if (Test-Path $agentsMd) {
        New-SymbolicLinkSafe -Source $agentsMd -Target (Join-Path $HOME '.agents\AGENTS.md') | Out-Null
    }
    Write-Host ""

    Write-Host "=============================="
    if ($DryRun) {
        Write-Info "Dry run complete. Run without -DryRun to apply changes."
    } else {
        Write-Success "Installation complete!"
        Write-Info "Restart your shell for OPENCODE_CONFIG_DIR to take effect."
    }
    Write-Host ""
}

# Check for admin rights on Windows (needed for symlinks)
if ($IsWindows -or ($PSVersionTable.PSEdition -eq 'Desktop')) {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if (-not $isAdmin -and -not $DryRun) {
        Write-Warn "Running without Administrator privileges. Symlink creation may fail."
        Write-Warn "Consider running PowerShell as Administrator, or enable Developer Mode."
        Write-Host ""
    }
}

Install-AgentConfigs

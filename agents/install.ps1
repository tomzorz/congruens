<#
.SYNOPSIS
    Install agent configurations by creating symlinks from standard tool locations
    to the shared config in ~/dotfiles/agents/

.DESCRIPTION
    Creates symbolic links so that OpenCode, Claude Code, and other agentic tools
    can share the same skill and agent definitions.

.PARAMETER DryRun
    Show what would be done without making changes

.PARAMETER Force
    Remove existing files/directories before creating symlinks

.EXAMPLE
    .\install.ps1
    
.EXAMPLE
    .\install.ps1 -DryRun
    
.EXAMPLE
    .\install.ps1 -Force
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Configuration
$DotfilesDir = if ($env:DOTFILES_DIR) { $env:DOTFILES_DIR } else { Join-Path $HOME 'dotfiles' }
$AgentsDir = Join-Path $DotfilesDir 'agents'

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

        if ($Force) {
            if ($DryRun) {
                Write-Info "Would remove existing: $Target"
            } else {
                Remove-Item -Path $Target -Recurse -Force
                Write-Warn "Removed existing: $Target"
            }
        } else {
            Write-Warn "Skipping (exists): $Target (use -Force to override)"
            return $false
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
    if (-not (Test-Path $AgentsDir)) {
        Write-Err "Agents directory not found: $AgentsDir"
        exit 1
    }

    Write-Info "Source: $AgentsDir"
    Write-Host ""

    # Claude Code symlinks
    Write-Host "Claude Code:"
    New-SymbolicLinkSafe -Source (Join-Path $AgentsDir 'skills') -Target (Join-Path $HOME '.claude\skills') | Out-Null
    New-SymbolicLinkSafe -Source (Join-Path $AgentsDir 'subagents') -Target (Join-Path $HOME '.claude\agents') | Out-Null
    # CLAUDE.md is the Claude Code equivalent of AGENTS.md
    New-SymbolicLinkSafe -Source (Join-Path $DotfilesDir 'AGENTS.md') -Target (Join-Path $HOME '.claude\CLAUDE.md') | Out-Null
    Write-Host ""

    # OpenCode symlinks
    Write-Host "OpenCode:"
    New-SymbolicLinkSafe -Source (Join-Path $AgentsDir 'skills') -Target (Join-Path $HOME '.opencode\skills') | Out-Null
    New-SymbolicLinkSafe -Source (Join-Path $AgentsDir 'subagents') -Target (Join-Path $HOME '.opencode\agents') | Out-Null
    New-SymbolicLinkSafe -Source (Join-Path $DotfilesDir 'AGENTS.md') -Target (Join-Path $HOME '.opencode\AGENTS.md') | Out-Null
    Write-Host ""

    # Agent Skills standard symlinks
    Write-Host "Agent Skills Standard:"
    New-SymbolicLinkSafe -Source (Join-Path $AgentsDir 'skills') -Target (Join-Path $HOME '.agents\skills') | Out-Null
    New-SymbolicLinkSafe -Source (Join-Path $DotfilesDir 'AGENTS.md') -Target (Join-Path $HOME '.agents\AGENTS.md') | Out-Null
    Write-Host ""

    Write-Host "=============================="
    if ($DryRun) {
        Write-Info "Dry run complete. Run without -DryRun to apply changes."
    } else {
        Write-Success "Installation complete!"
    }
    Write-Host ""
}

# Check for admin rights on Windows (needed for symlinks)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin -and -not $DryRun) {
    Write-Warn "Running without Administrator privileges. Symlink creation may fail."
    Write-Warn "Consider running PowerShell as Administrator, or enable Developer Mode."
    Write-Host ""
}

Install-AgentConfigs

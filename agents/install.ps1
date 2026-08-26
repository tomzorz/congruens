<#
.SYNOPSIS
    Install agent configurations for AI coding assistants.

.DESCRIPTION
    - Sets OPENCODE_CONFIG_DIR env var for OpenCode (no symlinks needed)
    - Creates symbolic links for Claude Code and Agent Skills standard

.PARAMETER DryRun
    Show what would be done without making changes

.PARAMETER CheckSettings
    Only report permission drift between the congruens seed and this machine's
    ~/.claude/settings.json, then exit. Never writes to settings.json.

.PARAMETER ApplySettings
    Overwrite this machine's command rules with the seed's, backing up
    settings.json first. Path and WebFetch rules are left alone.

.PARAMETER BaselineSettings
    Record the current seed as this machine's baseline, silencing drift you
    have already looked at and decided about.

.EXAMPLE
    .\install.ps1

.EXAMPLE
    .\install.ps1 -DryRun

.EXAMPLE
    .\install.ps1 -CheckSettings
#>

[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$CheckSettings,
    [switch]$ApplySettings,
    [switch]$BaselineSettings
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

<#
.SYNOPSIS
    Run the shared settings drift checker.

.DESCRIPTION
    The JSON set logic lives in one Python script rather than twice in bash and
    PowerShell, because a three-way diff maintained in two languages is a diff
    waiting to disagree with itself. Returns the script's exit code, or 2 when
    no usable interpreter is on PATH.
#>
function Invoke-DriftCheck {
    param([switch]$Baseline, [switch]$Apply)

    $pythonBin = $null
    # Not just Get-Command: on Windows, python3 on PATH is usually the Microsoft
    # Store's App Execution Alias, which exists, resolves, prints an ad for the
    # Store and exits 49. Only a binary that actually runs code counts.
    # The stub writes its ad to stderr, and $ErrorActionPreference = 'Stop'
    # promotes native stderr to a terminating NativeCommandError, which would
    # abort the probe on the first candidate instead of trying the next one.
    $previousPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        foreach ($candidate in @('python3', 'python', 'py')) {
            if (-not (Get-Command $candidate -ErrorAction SilentlyContinue)) { continue }
            try { & $candidate -c "import sys" *> $null } catch { continue }
            if ($LASTEXITCODE -eq 0) {
                $pythonBin = $candidate
                break
            }
        }
    } finally {
        $ErrorActionPreference = $previousPreference
    }
    if (-not $pythonBin) {
        Write-Warn "No working python3 on PATH, skipping settings drift check"
        return 2
    }

    $checkArgs = @(
        (Join-Path $AgentsDir 'check-settings-drift.py')
        '--seed', (Join-Path $ConfigDir 'claude-settings.json')
        '--live', (Join-Path $HOME '.claude\settings.json')
        '--snapshot', (Join-Path $HOME '.claude\.congruens-seed.json')
    )
    if ($Baseline) { $checkArgs += '--baseline' }
    if ($Apply) { $checkArgs += '--apply' }

    # Out-Host, not the output stream: the caller pipes this function's return
    # value around, and the report is for the human, not for the pipeline.
    & $pythonBin @checkArgs | Out-Host
    return $LASTEXITCODE
}

# Main installation
function Install-AgentConfigs {
    Write-Host ""
    Write-Host "Agent Configuration Installer"
    Write-Host "=============================="
    Write-Host ""

    # These are about settings.json only, so they run on their own and skip the
    # symlinking entirely. -ApplySettings is never part of a normal install run:
    # writing settings.json is the one thing the seed-once design exists to
    # prevent, so it only ever happens because someone asked for it by name.
    if ($ApplySettings) {
        exit (Invoke-DriftCheck -Apply)
    }
    if ($BaselineSettings) {
        exit (Invoke-DriftCheck -Baseline)
    }
    if ($CheckSettings) {
        $code = Invoke-DriftCheck
        if ($code -eq 0) { Write-Success "No permission drift against the congruens seed" }
        exit $code
    }

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
    # settings.json is per-machine: permissions and enabled plugins differ by host.
    # Seed it once as a real file, then never touch it again. Do NOT symlink -
    # New-SymbolicLinkSafe force-removes an existing target, which would silently
    # destroy a machine's local permission rules.
    $claudeSettings = Join-Path $HOME '.claude\settings.json'
    if (Test-Path $claudeSettings) {
        Write-Info "Kept existing: $claudeSettings (per-machine, not managed by congruens)"
        # Report-only. Seeded once means a permissions change in the repo has to
        # be replayed by hand on every host; this is what tells you a host is behind.
        Invoke-DriftCheck | Out-Null
    } elseif ($DryRun) {
        Write-Info "Would seed: $claudeSettings (copy, not symlink)"
    } else {
        Copy-Item -Path (Join-Path $ConfigDir 'claude-settings.json') -Destination $claudeSettings
        Write-Success "Seeded: $claudeSettings (copy - edit locally, will not be overwritten)"
        # A machine seeded now starts reconciled, so record the baseline that
        # lets later runs tell an upstream change from a local edit.
        Invoke-DriftCheck -Baseline | Out-Null
    }
    # AGENTS.md lives in the config dir alongside the skills and agent definitions,
    # not at the repo root. Pointing at the root made both symlinks silently skip.
    $agentsMd = Join-Path $ConfigDir 'AGENTS.md'
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

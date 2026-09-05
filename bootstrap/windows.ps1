#Requires -Version 7.0
<#
.SYNOPSIS
    Windows bootstrap script for Congruens.

.DESCRIPTION
    Automates Windows machine setup:
    1. Check prerequisites (PowerShell 7)
    2. Ensure package managers are available (winget, Scoop, Chocolatey)
    3. Read tool definitions from tools/*.json
    4. Install each tool using first available package manager
    5. Wire $PROFILE to source repo profile
    6. Configure oh-my-posh
    7. Create local config from defaults

.EXAMPLE
    .\windows.ps1
    
    Run the full bootstrap process.

.EXAMPLE
    .\windows.ps1 -SkipTools
    
    Run bootstrap without installing tools.
#>
[CmdletBinding()]
param(
    [switch]$SkipTools,
    [switch]$SkipProfile,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Colors for output
function Write-Step { param($Message) Write-Host "`n>> $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "   [OK] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "   [!] $Message" -ForegroundColor Yellow }
function Write-Failure { param($Message) Write-Host "   [X] $Message" -ForegroundColor Red }

# ============================================================================
# Prerequisites Check
# ============================================================================

Write-Step "Checking prerequisites..."

# Check PowerShell version
if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Failure "PowerShell 7+ is required. Current version: $($PSVersionTable.PSVersion)"
    Write-Host "   Install from: https://github.com/PowerShell/PowerShell/releases"
    exit 1
}
Write-Success "PowerShell $($PSVersionTable.PSVersion)"

# Check if running as admin (warning, not required)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($isAdmin) {
    Write-Success "Running as Administrator"
} else {
    Write-Warning "Not running as Administrator - some tools may require elevation"
}

# ============================================================================
# Package Manager Setup
# ============================================================================

Write-Step "Setting up package managers..."

# Check for winget
$hasWinget = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
if ($hasWinget) {
    Write-Success "winget is available"
} else {
    Write-Warning "winget not found"
}

# Check for Scoop
$hasScoop = $null -ne (Get-Command scoop -ErrorAction SilentlyContinue)
if ($hasScoop) {
    Write-Success "Scoop is available"
} else {
    Write-Host "   Installing Scoop..." -ForegroundColor Gray
    try {
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
        $hasScoop = $true
        Write-Success "Scoop installed"
    }
    catch {
        Write-Warning "Failed to install Scoop: $_"
    }
}

# Check for Chocolatey
$hasChoco = $null -ne (Get-Command choco -ErrorAction SilentlyContinue)
if ($hasChoco) {
    Write-Success "Chocolatey is available"
} else {
    Write-Host "   Installing Chocolatey..." -ForegroundColor Gray
    try {
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $hasChoco = $true
        Write-Success "Chocolatey installed"
    }
    catch {
        Write-Warning "Failed to install Chocolatey: $_"
    }
}

if (-not $hasWinget -and -not $hasScoop -and -not $hasChoco) {
    Write-Failure "No package manager available. Please install winget, Scoop, or Chocolatey manually."
    exit 1
}

# ============================================================================
# Repo Root
# ============================================================================

$repoRoot = Split-Path -Parent $PSScriptRoot

# ============================================================================
# Tool Installation
# ============================================================================

if (-not $SkipTools) {
    Write-Step "Installing tools..."

    $toolsPath = Join-Path $repoRoot "tools"
    if (-not (Test-Path $toolsPath)) {
        Write-Warning "Tools directory not found at $toolsPath"
    } else {
        $toolFiles = Get-ChildItem -Path $toolsPath -Filter "*.json"
        $totalTools = $toolFiles.Count
        $currentTool = 0
        $hasSelfManaged = $false

        foreach ($toolFile in $toolFiles) {
            $currentTool++
            $tool = Get-Content $toolFile.FullName | ConvertFrom-Json
            $toolName = $tool.name

            Write-Host "   [$currentTool/$totalTools] $toolName..." -NoNewline -ForegroundColor Gray

            # Self-managed tools are handled after this loop by the Congruens
            # module, so there is one implementation of the download/checksum
            # logic instead of one per platform bootstrap.
            if ($tool.install.windows.github) {
                Write-Host " self-managed (handled below)" -ForegroundColor DarkGray
                $hasSelfManaged = $true
                continue
            }

            # Check if already installed via verify command
            if ($tool.verify) {
                $verifyCmd = $tool.verify -split ' ' | Select-Object -First 1
                if (Get-Command $verifyCmd -ErrorAction SilentlyContinue) {
                    Write-Host " already installed" -ForegroundColor DarkGray
                    continue
                }
            }

            $installed = $false
            $windowsInstall = $tool.install.windows

            # Try winget first
            if ($hasWinget -and $windowsInstall.winget) {
                try {
                    $null = winget install --id $windowsInstall.winget --silent --accept-package-agreements --accept-source-agreements 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host " OK (winget)" -ForegroundColor Green
                        $installed = $true
                    }
                }
                catch { }
            }

            # Fall back to scoop
            if (-not $installed -and $hasScoop -and $windowsInstall.scoop) {
                try {
                    scoop install $windowsInstall.scoop 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host " OK (scoop)" -ForegroundColor Green
                        $installed = $true
                    }
                }
                catch { }
            }

            # Fall back to choco
            if (-not $installed -and $hasChoco -and $windowsInstall.choco) {
                try {
                    choco install $windowsInstall.choco -y --no-progress 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host " OK (choco)" -ForegroundColor Green
                        $installed = $true
                    }
                }
                catch { }
            }

            # Fall back to cargo for Rust tools with no package on this platform
            if (-not $installed -and $windowsInstall.cargo -and (Get-Command cargo -ErrorAction SilentlyContinue)) {
                try {
                    cargo install --quiet $windowsInstall.cargo 2>&1 | Out-Null
                    if ($LASTEXITCODE -eq 0) {
                        Write-Host " OK (cargo)" -ForegroundColor Green
                        $installed = $true
                    }
                }
                catch { }
            }

            if (-not $installed) {
                Write-Host " SKIP (no package available)" -ForegroundColor Yellow
            }
        }

        # Self-managed tools: delegate to the Congruens module so the download,
        # checksum and PATH logic lives in exactly one place.
        if ($hasSelfManaged) {
            Write-Step "Installing self-managed tools (GitHub releases)..."
            try {
                $psModuleDir = Join-Path $repoRoot 'powershell'
                if ($env:PSModulePath -notlike "*$psModuleDir*") {
                    $env:PSModulePath = "$psModuleDir$([IO.Path]::PathSeparator)$env:PSModulePath"
                }
                Import-Module Congruens -Force -ErrorAction Stop
                Install-CongruensTool -All
            }
            catch {
                Write-Warning "Self-managed tool install failed: $_"
                Write-Warning "Run 'cgrtool -All' after restarting your shell."
            }
        }
    }
}

# ============================================================================
# Profile Configuration
# ============================================================================

if (-not $SkipProfile) {
    Write-Step "Configuring PowerShell profile..."

    $profileDir = Split-Path $PROFILE
    if (-not (Test-Path $profileDir)) {
        New-Item -Path $profileDir -ItemType Directory -Force | Out-Null
    }

    $profileSourcePath = Join-Path $repoRoot "powershell" "profile.ps1"
    $profileContent = @"
# Congruens - Cross-platform CLI experience
# Source the congruens profile
. "$profileSourcePath"
"@

    $existingProfile = if (Test-Path $PROFILE) { Get-Content $PROFILE -Raw } else { "" }
    
    if ($existingProfile -like "*$profileSourcePath*") {
        Write-Success "Profile already configured"
    } else {
        if ($existingProfile -and -not $Force) {
            # Append to existing profile
            $profileContent = "`n$profileContent"
            Add-Content -Path $PROFILE -Value $profileContent
            Write-Success "Appended to existing profile"
        } else {
            # Create new profile
            Set-Content -Path $PROFILE -Value $profileContent
            Write-Success "Created new profile"
        }
    }
}

# ============================================================================
# oh-my-posh Configuration
# ============================================================================

Write-Step "Configuring oh-my-posh..."

$ompInstalled = $null -ne (Get-Command oh-my-posh -ErrorAction SilentlyContinue)

if ($ompInstalled) {
    Write-Success "oh-my-posh is installed"
    
    $themePath = Join-Path $repoRoot "omp" "congruens.omp.json"
    if (Test-Path $themePath) {
        Write-Success "Theme found at $themePath"
        Write-Host "   Theme will be applied on next shell startup" -ForegroundColor Gray
    } else {
        Write-Warning "Theme not found at $themePath"
    }
} else {
    Write-Warning "oh-my-posh not installed - run tools installation first"
}

# ============================================================================
# Nerd Font Installation
# ============================================================================

Write-Step "Installing CaskaydiaCove Nerd Font..."

# Check if the font is already installed
$fontInstalled = Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue | 
    Get-Member -MemberType NoteProperty | 
    Where-Object { $_.Name -like "*CaskaydiaCove*" -or $_.Name -like "*Cascadia*Nerd*" }

if ($fontInstalled) {
    Write-Success "CaskaydiaCove Nerd Font is already installed"
} else {
    if ($hasWinget) {
        try {
            Write-Host "   Installing via winget..." -ForegroundColor Gray
            $null = winget install --id "DEVCOM.JetBrainsMonoNerdFont" --source winget --silent --accept-package-agreements --accept-source-agreements 2>&1
            # Note: winget package for CaskaydiaCove may vary, trying common alternatives
            # Download and install manually as winget font packages can be unreliable
            Write-Host "   Downloading CaskaydiaCove Nerd Font..." -ForegroundColor Gray
            $fontUrl = "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/CascadiaCode.zip"
            $tempZip = Join-Path $env:TEMP "CascadiaCode.zip"
            $tempDir = Join-Path $env:TEMP "CascadiaCode"
            
            Invoke-WebRequest -Uri $fontUrl -OutFile $tempZip -UseBasicParsing
            
            # Extract the zip
            if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force }
            Expand-Archive -Path $tempZip -DestinationPath $tempDir -Force
            
            # Install fonts to user fonts folder
            $userFontsDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
            if (-not (Test-Path $userFontsDir)) {
                New-Item -Path $userFontsDir -ItemType Directory -Force | Out-Null
            }
            
            # Copy font files
            $fontFiles = Get-ChildItem -Path $tempDir -Filter "*.ttf" -Recurse
            $installedCount = 0
            foreach ($fontFile in $fontFiles) {
                $destPath = Join-Path $userFontsDir $fontFile.Name
                Copy-Item -Path $fontFile.FullName -Destination $destPath -Force
                
                # Register font in user registry
                $fontName = [System.IO.Path]::GetFileNameWithoutExtension($fontFile.Name)
                $null = New-ItemProperty -Path "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name "$fontName (TrueType)" -Value $destPath -PropertyType String -Force -ErrorAction SilentlyContinue
                $installedCount++
            }
            
            # Cleanup
            Remove-Item $tempZip -Force -ErrorAction SilentlyContinue
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            
            Write-Success "Installed $installedCount CaskaydiaCove Nerd Font files"
        }
        catch {
            Write-Warning "Failed to install font: $_"
            Write-Host "   You can install manually: winget install nerdfonts.CascadiaCode" -ForegroundColor Gray
        }
    } else {
        Write-Warning "winget not available - please install CaskaydiaCove Nerd Font manually"
    }
}

# ============================================================================
# Claude Code Notifications (peon-ping)
# ============================================================================

Write-Step "Setting up peon-ping (Claude Code notifications)..."

# peon-ping (https://github.com/PeonPing/peon-ping) plays Warcraft peon voice
# lines on Claude Code lifecycle events. Its installer registers hooks in
# ~/.claude/settings.json, so it must only run AFTER agents/install.ps1 has
# seeded that file - a hook-only settings.json created first would make the
# seed step skip, and the machine would silently miss the shared config.

$peonHooksDir = Join-Path $env:USERPROFILE ".claude\hooks\peon-ping"
$peonConfig = Join-Path $peonHooksDir "config.json"
$peonConfigSeed = Join-Path $repoRoot "agents\config\peon-ping.json"
$claudeSettings = Join-Path $env:USERPROFILE ".claude\settings.json"

# Put the shared config and the sound packs it names in place. Runs whether or
# not this bootstrap did the install, because the two drift apart: an install
# from before the seed existed, or a config someone deleted, would otherwise
# never be repaired - the old "hooks dir exists, skip everything" short-circuit
# meant a machine could have peon-ping and no shared config forever.
#
# -Force right after a fresh install, so the shared config beats the default the
# installer just wrote. Without it per-machine tweaks survive and only a missing
# config gets restored.
function Initialize-PeonConfig {
    param([switch]$Force)

    if (-not (Test-Path $peonConfigSeed)) {
        Write-Warning "peon-ping config seed not found at $peonConfigSeed"
        return
    }

    if ((Test-Path $peonConfig) -and (-not $Force)) {
        Write-Success "peon-ping config already present"
    } else {
        Copy-Item -Path $peonConfigSeed -Destination $peonConfig -Force
        Write-Success "Seeded shared peon-ping config"
    }

    # The seed's "packs" field is congruens's own (peon-ping ignores it): the
    # shared roster of sound packs to pull onto every machine. Each pack is a
    # directory under packs\, so install only the ones that aren't there yet.
    $roster = @((Get-Content $peonConfigSeed -Raw | ConvertFrom-Json).packs)
    $missing = @($roster | Where-Object { $_ -and -not (Test-Path (Join-Path $peonHooksDir "packs\$_")) })
    if ($missing.Count -eq 0) {
        Write-Success "peon-ping sound packs already installed"
        return
    }

    & powershell -ExecutionPolicy Bypass -File (Join-Path $peonHooksDir "peon.ps1") packs install ($missing -join ",")
    if ($LASTEXITCODE -ne 0) { Write-Warning "Some peon-ping packs failed to install" }
}

# --- congruens Windows normalizations ---
# Idempotent, and runs on every bootstrap rather than only after a fresh
# install: peon's own updater re-adds the full hook set and the BOM, and the
# resulting Claude Desktop breakage is bad enough that a bootstrap run should
# repair it without needing peon to be reinstalled first.
function Set-PeonWindowsNormalizations {
    # 1) On Windows, peon renders desktop notifications as PowerShell-branded
    #    toasts: it has no Windows overlay, the nice center banner (orc icon,
    #    colour-by-source) is macOS-only. Turn them off for Windows only, so it
    #    plays sounds without the toast spam. The shared seed keeps
    #    desktop_notifications=true so Mac/Linux still get peon's native overlay.
    if (Test-Path $peonConfig) {
        $peonCfg = Get-Content $peonConfig -Raw | ConvertFrom-Json
        if ($peonCfg.desktop_notifications) {
            $peonCfg.desktop_notifications = $false
            $peonCfg | ConvertTo-Json -Depth 20 | Set-Content -Path $peonConfig -Encoding utf8
            Write-Success "Windows: disabled peon desktop notifications (sounds only)"
        }
    }

    # 2) peon's installer subscribes to ~10 hook events, including PreToolUse
    #    which fires on EVERY tool call, and rewrites settings.json with a UTF-8
    #    BOM via Windows PowerShell 5.1 Set-Content. The BOM makes Claude
    #    Desktop's strict JSON parser reject its own config; PreToolUse floods
    #    the app with a PowerShell spawn per tool call that can leak and
    #    destabilise it. Trim to the low-frequency events and rewrite as UTF-8
    #    without a BOM.
    $peonDropEvents = @('SubagentStart', 'PreToolUse', 'PostToolUseFailure', 'UserPromptSubmit')
    if (-not (Test-Path $claudeSettings)) {
        Write-Warning "~/.claude/settings.json not found - skipping peon hook trim"
        return
    }
    try {
        $s = Get-Content $claudeSettings -Raw | ConvertFrom-Json
        if ($s.hooks) {
            $dropped = @()
            foreach ($ev in $peonDropEvents) {
                if ($s.hooks.PSObject.Properties.Name -contains $ev) {
                    $s.hooks.PSObject.Properties.Remove($ev)
                    $dropped += $ev
                }
            }
            $settingsJson = $s | ConvertTo-Json -Depth 100
            [System.IO.File]::WriteAllText($claudeSettings, $settingsJson, [System.Text.UTF8Encoding]::new($false))
            if ($dropped) {
                Write-Success "Trimmed peon hooks ($($dropped -join ', ')) and stripped settings.json BOM"
            } else {
                Write-Success "peon hooks already trimmed; rewrote settings.json without BOM"
            }
        }
    } catch {
        Write-Warning "Could not normalize peon hooks in settings.json: $_"
    }
}

$peonReady = $false
$peonFresh = $false

if (Test-Path $peonHooksDir) {
    # Install-only by design: an existing peon-ping is never upgraded here.
    # Its config and Windows normalizations still get checked.
    Write-Success "peon-ping already installed (re-run its installer to update)"
    $peonReady = $true
} elseif (-not (Test-Path $claudeSettings)) {
    Write-Warning "~/.claude/settings.json not seeded yet - run agents/install.ps1 first, then re-run this bootstrap to get peon-ping"
} else {
    # install.ps1 dot-sources scripts/ from its repo, so a single-file
    # download does not run (verified 2026-08-05). Fetch the whole repo zip.
    $peonZip = Join-Path $env:TEMP "peon-ping-main.zip"
    $peonSrc = Join-Path $env:TEMP "peon-ping-main"
    try {
        Invoke-WebRequest -Uri "https://github.com/PeonPing/peon-ping/archive/refs/heads/main.zip" -OutFile $peonZip -UseBasicParsing
        Expand-Archive -Path $peonZip -DestinationPath $env:TEMP -Force
        & powershell -ExecutionPolicy Bypass -File (Join-Path $peonSrc "install.ps1") -Global
        if ((Test-Path $peonHooksDir) -and $LASTEXITCODE -eq 0) {
            Write-Success "peon-ping installed and hooks registered"
            $peonReady = $true
            $peonFresh = $true
        } else {
            Write-Warning "peon-ping install failed - see https://github.com/PeonPing/peon-ping"
        }
    }
    catch {
        Write-Warning "peon-ping install failed: $_"
    }
    finally {
        Remove-Item $peonZip -ErrorAction SilentlyContinue
        Remove-Item $peonSrc -Recurse -ErrorAction SilentlyContinue
    }
}

if ($peonReady) {
    Initialize-PeonConfig -Force:$peonFresh
    Set-PeonWindowsNormalizations
}

# ============================================================================
# Summary
# ============================================================================

Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host " Bootstrap Complete!" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart your terminal or run: . `$PROFILE"
Write-Host ""
Write-Host "  2. Configure Windows Terminal to use CaskaydiaCove Nerd Font:" -ForegroundColor Yellow
Write-Host "     - Open Windows Terminal Settings (Ctrl+,)"
Write-Host "     - Go to Profiles > Defaults > Appearance"
Write-Host "     - Set Font face to: CaskaydiaCove Nerd Font"
Write-Host "     - Save and restart Windows Terminal"
Write-Host ""
Write-Host "  For VS Code integrated terminal, add to settings.json:" -ForegroundColor Yellow
Write-Host "     `"terminal.integrated.fontFamily`": `"CaskaydiaCove Nerd Font`""
Write-Host ""
Write-Host "Available commands:" -ForegroundColor Yellow
Write-Host "  mkcd <dir>     - Create directory and cd into it"
Write-Host "  open [path]    - Open in file explorer"
Write-Host "  which <cmd>    - Find command location"
Write-Host "  path show      - Display PATH entries"
Write-Host "  path add <dir> - Add to session PATH"
Write-Host ""

#Requires -Version 7.0
<#
.SYNOPSIS
    Windows bootstrap script for Congruens.

.DESCRIPTION
    Automates Windows machine setup:
    1. Check prerequisites (PowerShell 7)
    2. Install Chocolatey and/or ensure winget is available
    3. Read tool definitions from tools/*.json
    4. Install each tool using first available package manager
    5. Clone dotfiles to ~/dotfiles (if not exists)
    6. Wire $PROFILE to source repo profile
    7. Configure oh-my-posh
    8. Create local config from defaults

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
    Write-Warning "winget not found - will use Chocolatey only"
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

if (-not $hasWinget -and -not $hasChoco) {
    Write-Failure "No package manager available. Please install winget or Chocolatey manually."
    exit 1
}

# ============================================================================
# Dotfiles Setup
# ============================================================================

Write-Step "Setting up dotfiles..."

$dotfilesPath = Join-Path $HOME "dotfiles"
$repoRoot = Split-Path -Parent $PSScriptRoot

if (Test-Path $dotfilesPath) {
    Write-Success "Dotfiles already exist at $dotfilesPath"
} else {
    Write-Host "   Linking dotfiles to $dotfilesPath..." -ForegroundColor Gray
    
    try {
        # Try to create junction (works without admin)
        cmd /c mklink /J "$dotfilesPath" "$repoRoot" 2>$null
        if (Test-Path $dotfilesPath) {
            Write-Success "Linked dotfiles to $dotfilesPath"
        } else {
            # Fall back to copy
            Copy-Item -Path $repoRoot -Destination $dotfilesPath -Recurse
            Write-Success "Copied dotfiles to $dotfilesPath"
        }
    }
    catch {
        Write-Failure "Could not set up dotfiles: $_"
        exit 1
    }
}

# ============================================================================
# Tool Installation
# ============================================================================

if (-not $SkipTools) {
    Write-Step "Installing tools..."

    $toolsPath = Join-Path $dotfilesPath "tools"
    if (-not (Test-Path $toolsPath)) {
        Write-Warning "Tools directory not found at $toolsPath"
    } else {
        $toolFiles = Get-ChildItem -Path $toolsPath -Filter "*.json"
        $totalTools = $toolFiles.Count
        $currentTool = 0

        foreach ($toolFile in $toolFiles) {
            $currentTool++
            $tool = Get-Content $toolFile.FullName | ConvertFrom-Json
            $toolName = $tool.name
            
            Write-Host "   [$currentTool/$totalTools] $toolName..." -NoNewline -ForegroundColor Gray
            
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

            if (-not $installed) {
                Write-Host " SKIP (no package available)" -ForegroundColor Yellow
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

    $profileContent = @'
# Congruens - Cross-platform CLI experience
# Source the dotfiles profile
. "$HOME/dotfiles/powershell/profile.ps1"
'@

    $existingProfile = if (Test-Path $PROFILE) { Get-Content $PROFILE -Raw } else { "" }
    
    if ($existingProfile -like "*dotfiles/powershell/profile.ps1*") {
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
    
    $themePath = Join-Path $dotfilesPath "omp" "congruens.omp.json"
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
            $null = winget install --id "chrisant996.Clink" --source winget --silent 2>&1  # This is a placeholder
            
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
# Local Config Setup
# ============================================================================

Write-Step "Setting up configuration..."

$configPath = Join-Path $dotfilesPath "config"
$defaultsPath = Join-Path $configPath "congruens.defaults.json"
$localPath = Join-Path $configPath "congruens.local.json"

if (Test-Path $localPath) {
    Write-Success "Local config already exists"
} elseif (Test-Path $defaultsPath) {
    Copy-Item -Path $defaultsPath -Destination $localPath
    Write-Success "Created local config from defaults"
} else {
    Write-Warning "Defaults config not found"
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

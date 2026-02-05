<#
.SYNOPSIS
    Windows Sandbox bootstrap script for Congruens.

.DESCRIPTION
    Prepares a fresh Windows Sandbox environment by installing:
    1. WinGet (via Microsoft.WinGet.Client PowerShell module)
    2. Windows Terminal
    3. PowerShell 7
    
    After running this script, you can run windows.ps1 to complete the full bootstrap.

.EXAMPLE
    .\windows-sandbox.ps1
    
    Install prerequisites in Windows Sandbox.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$progressPreference = 'silentlyContinue'

# Colors for output
function Write-Step { param($Message) Write-Host "`n>> $Message" -ForegroundColor Cyan }
function Write-Success { param($Message) Write-Host "   [OK] $Message" -ForegroundColor Green }
function Write-Warning { param($Message) Write-Host "   [!] $Message" -ForegroundColor Yellow }
function Write-Failure { param($Message) Write-Host "   [X] $Message" -ForegroundColor Red }

Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host " Congruens - Windows Sandbox Bootstrap" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

# ============================================================================
# Install WinGet
# ============================================================================

Write-Step "Installing WinGet..."

# Check if winget is already available
$hasWinget = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)

if ($hasWinget) {
    Write-Success "WinGet is already installed"
} else {
    Write-Host "   Installing WinGet PowerShell module from PSGallery..." -ForegroundColor Gray
    
    try {
        # Install NuGet provider (required for Install-Module)
        Install-PackageProvider -Name NuGet -Force | Out-Null
        Write-Success "NuGet provider installed"
    }
    catch {
        Write-Failure "Failed to install NuGet provider: $_"
        exit 1
    }

    try {
        # Install the Microsoft.WinGet.Client module
        Install-Module -Name Microsoft.WinGet.Client -Force -Repository PSGallery | Out-Null
        Write-Success "Microsoft.WinGet.Client module installed"
    }
    catch {
        Write-Failure "Failed to install Microsoft.WinGet.Client module: $_"
        exit 1
    }

    try {
        # Use Repair-WinGetPackageManager to bootstrap WinGet
        Write-Host "   Using Repair-WinGetPackageManager cmdlet to bootstrap WinGet..." -ForegroundColor Gray
        Repair-WinGetPackageManager -AllUsers
        Write-Success "WinGet bootstrapped successfully"
    }
    catch {
        Write-Failure "Failed to bootstrap WinGet: $_"
        exit 1
    }

    # Verify winget is now available
    $hasWinget = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
    if ($hasWinget) {
        Write-Success "WinGet is now available"
    } else {
        Write-Warning "WinGet may require a new terminal session to be available"
    }
}

# ============================================================================
# Install Windows Terminal
# ============================================================================

Write-Step "Installing Windows Terminal..."

# Check if Windows Terminal is already available
$hasWT = $null -ne (Get-Command wt -ErrorAction SilentlyContinue)

if ($hasWT) {
    Write-Success "Windows Terminal is already installed"
} else {
    Write-Host "   Installing via winget..." -ForegroundColor Gray
    
    try {
        winget install "windows terminal" --source "msstore" --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Windows Terminal installed"
        } else {
            Write-Failure "Failed to install Windows Terminal (exit code: $LASTEXITCODE)"
            exit 1
        }
    }
    catch {
        Write-Failure "Failed to install Windows Terminal: $_"
        exit 1
    }
}

# ============================================================================
# Install PowerShell 7
# ============================================================================

Write-Step "Installing PowerShell 7..."

# Check if PowerShell 7 is already available
$pwshPath = Get-Command pwsh -ErrorAction SilentlyContinue
if ($pwshPath) {
    $pwshVersion = & pwsh -NoProfile -Command '$PSVersionTable.PSVersion.ToString()'
    Write-Success "PowerShell $pwshVersion is already installed"
} else {
    Write-Host "   Installing via winget..." -ForegroundColor Gray
    
    try {
        winget install --id Microsoft.PowerShell --source winget --silent --accept-package-agreements --accept-source-agreements
        if ($LASTEXITCODE -eq 0) {
            Write-Success "PowerShell 7 installed"
        } else {
            Write-Failure "Failed to install PowerShell 7 (exit code: $LASTEXITCODE)"
            exit 1
        }
    }
    catch {
        Write-Failure "Failed to install PowerShell 7: $_"
        exit 1
    }
}

# ============================================================================
# Summary
# ============================================================================

Write-Host "`n" + ("=" * 60) -ForegroundColor Cyan
Write-Host " Sandbox Bootstrap Complete!" -ForegroundColor Green
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""
Write-Host "Installed:" -ForegroundColor Yellow
Write-Host "  - WinGet (Windows Package Manager)"
Write-Host "  - Windows Terminal"
Write-Host "  - PowerShell 7"
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Open PowerShell 7 (pwsh) or Windows Terminal"
Write-Host "  2. Navigate to this directory"
Write-Host "  3. Run: .\windows.ps1"
Write-Host ""

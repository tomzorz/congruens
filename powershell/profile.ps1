# Congruens PowerShell Profile
# This file is sourced by the user's $PROFILE
# Keep it minimal - just load the module and initialize oh-my-posh

# Add module path
$dotfilesPath = Join-Path $HOME "dotfiles" "powershell"
if ($env:PSModulePath -notlike "*$dotfilesPath*") {
    $env:PSModulePath = "$dotfilesPath$([IO.Path]::PathSeparator)$env:PSModulePath"
}

# Import module
Import-Module Congruens -ErrorAction SilentlyContinue

# Initialize oh-my-posh with custom theme
$themePath = Join-Path $HOME "dotfiles" "omp" "congruens.omp.json"
if (Test-Path $themePath) {
    oh-my-posh init pwsh --config $themePath | Invoke-Expression
}

# Show Message of the Day
Show-Motd

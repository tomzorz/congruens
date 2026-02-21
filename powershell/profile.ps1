# Congruens PowerShell Profile
# This file is sourced by the user's $PROFILE
# Keep it minimal - just load the module and initialize oh-my-posh

# Resolve paths relative to this script's location (powershell/ directory)
$congruensRoot = Split-Path -Parent $PSScriptRoot

# Add module path
$modulePath = $PSScriptRoot
if ($env:PSModulePath -notlike "*$modulePath*") {
    $env:PSModulePath = "$modulePath$([IO.Path]::PathSeparator)$env:PSModulePath"
}

# Import module
Import-Module Congruens -ErrorAction SilentlyContinue

# Initialize oh-my-posh with custom theme
$themePath = Join-Path $congruensRoot "omp" "congruens.omp.json"
if (Test-Path $themePath) {
    oh-my-posh init pwsh --config $themePath | Invoke-Expression
}

# Show Message of the Day
Show-Motd

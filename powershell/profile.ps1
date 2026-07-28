# Congruens PowerShell Profile
# This file is sourced by the user's $PROFILE
# Keep it minimal - just load the module and initialize oh-my-posh

# Resolve paths relative to this script's location (powershell/ directory)
$congruensRoot = Split-Path -Parent $PSScriptRoot

# Ensure this repo's module path is discoverable
$modulePath = $PSScriptRoot
if ($env:PSModulePath -notlike "*$modulePath*") {
    $env:PSModulePath = "$modulePath$([IO.Path]::PathSeparator)$env:PSModulePath"
}

# Self-managed tools (cgrtool / cgrupdate) live here. Prepended rather than
# appended so a congruens-owned binary wins over a stale package-manager copy
# of the same tool -- which is the whole point of managing it ourselves.
$congruensBin = Join-Path (Join-Path $HOME '.congruens') 'bin'
if ((Test-Path $congruensBin) -and ($env:PATH -notlike "*$congruensBin*")) {
    $env:PATH = "$congruensBin$([IO.Path]::PathSeparator)$env:PATH"
}

# Import module
Import-Module Congruens -ErrorAction SilentlyContinue

# Initialize oh-my-posh with custom theme
$themePath = Join-Path $congruensRoot "omp" "congruens.omp.json"
if (Test-Path $themePath) {
    oh-my-posh init pwsh --config $themePath | Invoke-Expression
}

# Initialize tirith shell hook (terminal security guard)
if (Get-Command tirith -ErrorAction SilentlyContinue) {
    tirith init --shell pwsh | Invoke-Expression
}

# Show Message of the Day
Show-Motd

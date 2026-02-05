# Congruens PowerShell Module
# A shared cross-platform CLI experience

# Get the module path
$ModulePath = $PSScriptRoot

# Dot-source all Private functions
$PrivatePath = Join-Path $ModulePath 'Private'
if (Test-Path $PrivatePath) {
    Get-ChildItem -Path $PrivatePath -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}

# Dot-source all Public functions
$PublicPath = Join-Path $ModulePath 'Public'
if (Test-Path $PublicPath) {
    Get-ChildItem -Path $PublicPath -Filter '*.ps1' -Recurse | ForEach-Object {
        . $_.FullName
    }
}

# Create aliases
Set-Alias -Name 'open' -Value 'Open-Path' -Scope Global
Set-Alias -Name 'path' -Value 'Invoke-PathCommand' -Scope Global

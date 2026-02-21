<#
.SYNOPSIS
    Displays the Message of the Day (MOTD) for Congruens.

.DESCRIPTION
    Shows a welcome message and system information when a new PowerShell session starts.
    Invokes fastfetch for system information if available.
#>

function Show-Motd {
    <#
    .SYNOPSIS
        Display the Congruens Message of the Day.
    
    .DESCRIPTION
        Shows a welcome banner and invokes fastfetch for system information.
        Called automatically when a new PowerShell session is initialized.
    
    .PARAMETER SkipFastfetch
        Skip running fastfetch even if it's installed.
    
    .EXAMPLE
        Show-Motd
        
        Displays the MOTD with fastfetch system info.
    
    .EXAMPLE
        Show-Motd -SkipFastfetch
        
        Displays only the welcome message without system info.
    #>
    [CmdletBinding()]
    param(
        [switch]$SkipFastfetch
    )

    # Welcome banner
    Write-Host ""
    Write-Host "  Welcome to " -NoNewline -ForegroundColor White
    Write-Host "Congruens!" -NoNewline -ForegroundColor Cyan
    Write-Host " (run `cgrman` for help)" -ForegroundColor DarkGray
    Write-Host ""

    # Run fastfetch if available and not skipped
    if (-not $SkipFastfetch) {
        $fastfetchCmd = Get-Command fastfetch -ErrorAction SilentlyContinue
        if ($fastfetchCmd) {
            & fastfetch
            Write-Host ""
        }
    }

    # Quick tips (rotate through different tips based on day)
    $tips = @(
        "Use 'mkcd <dir>' to create a directory and cd into it.",
        "Use 'open .' to open the current directory in your file explorer.",
        "Use 'which <command>' to find where a command is located.",
        "Use 'cgrpath show' to display your PATH entries.",
        "Use 'cgrpath addsession <dir>' to add a folder to your session PATH.",
        "Use 'cgrpath addpermanent <dir>' to persist a folder to your PATH.",
        "Use 'cgrenv show' to list all environment variables.",
        "Use 'cgrenv addsession <name> <value>' to set a session env variable.",
        "Use 'cgrenv addpermanent <name> <value>' to persist an env variable.",
        "Use 'll' for enhanced directory listing with eza."
    )
    
    $tipIndex = Get-Random -Maximum $tips.Count
    $tip = $tips[$tipIndex]
    
    Write-Host "  Tip: " -NoNewline -ForegroundColor Yellow
    Write-Host $tip -ForegroundColor Gray
    Write-Host ""
}

# Alias for convenience
function motd {
    <#
    .SYNOPSIS
        Alias for Show-Motd - Message of the Day.
    #>
    [CmdletBinding()]
    param(
        [switch]$SkipFastfetch
    )

    Show-Motd @PSBoundParameters
}

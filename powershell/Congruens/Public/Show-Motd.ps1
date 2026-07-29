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

    # Run fastfetch if available and not skipped (kill it if it takes over 1s)
    if (-not $SkipFastfetch) {
        $fastfetchCmd = Get-Command fastfetch -ErrorAction SilentlyContinue
        if ($fastfetchCmd) {
            # Use the trimmed congruens config (essentials only) when present;
            # plain `fastfetch` still gives the full output on demand.
            $congruensRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
            $ffConfig = Join-Path (Join-Path $congruensRoot 'config') 'fastfetch.jsonc'
            $ffArgs = if (Test-Path $ffConfig) { @('--config', $ffConfig) } else { @() }

            $proc = if ($ffArgs.Count -gt 0) {
                Start-Process -FilePath $fastfetchCmd.Source -ArgumentList $ffArgs -NoNewWindow -PassThru
            } else {
                Start-Process -FilePath $fastfetchCmd.Source -NoNewWindow -PassThru
            }
            if (-not $proc.WaitForExit(1000)) {
                $proc.Kill()
                Write-Host "   fastfetch timed out" -ForegroundColor DarkGray
            }
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
        "Use 'll' for enhanced directory listing with eza.",
        "Use 'setjump <alias>' to bookmark the current directory.",
        "Use 'jump <alias>' to jump to a bookmarked directory.",
        "Use 'jump' with no args to list all your bookmarks.",
        "Use 'cgrman' to browse all Congruens commands, tools, and dev environments.",
        "Use 'cgrinstall -List' to see available dev environments and their status.",
        "Use 'cgrinstall <name>' to install a dev environment (dotnet, node, python).",
        "Use 'cgrtool <name>' to install a self-managed tool from its GitHub release.",
        "Use 'cgrupdate' to update self-managed tools like yt-dlp to the latest release.",
        "Use 'tirith-check check -- <cmd>' to analyze a command before running it.",
        "Use 'tirith-check run <url>' as a safe replacement for curl | bash."
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

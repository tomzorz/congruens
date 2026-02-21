<#
.SYNOPSIS
    Interactive browser for Congruens tool definitions and built-in commands.

.DESCRIPTION
    Displays built-in commands and tool definitions from the tools/ directory in
    an interactive viewer. Use left/right arrow keys to navigate, and 'q' or
    Escape to quit.
#>

function Show-CongruensManual {
    <#
    .SYNOPSIS
        Browse built-in commands and tool definitions interactively.
    
    .DESCRIPTION
        Displays built-in Congruens commands first, followed by external tools
        from tools/*.json. Navigate with arrow keys.
    
    .EXAMPLE
        Show-CongruensManual
        
        Opens the interactive tool browser.
    
    .EXAMPLE
        cgrman
        
        Same as Show-CongruensManual.
    #>
    [CmdletBinding()]
    param()

    # --- Built-in command definitions ---
    $builtinCommands = @(
        [PSCustomObject]@{
            Name        = 'cgrpath'
            Category    = 'builtin'
            Description = 'Congruens PATH environment variable management'
            Usage       = @(
                [PSCustomObject]@{ Command = 'cgrpath show';                  Info = 'Display PATH entries, one per line with index' }
                [PSCustomObject]@{ Command = 'cgrpath addsession <dir>';      Info = 'Add a directory to the current session PATH' }
                [PSCustomObject]@{ Command = 'cgrpath addpermanent <dir>';    Info = 'Add a directory to PATH permanently' }
                [PSCustomObject]@{ Command = 'cgrpath remove <dir>';          Info = 'Remove a directory from session PATH' }
            )
        }
        [PSCustomObject]@{
            Name        = 'cgrenv'
            Category    = 'builtin'
            Description = 'Congruens environment variable management'
            Usage       = @(
                [PSCustomObject]@{ Command = 'cgrenv show';                           Info = 'Display all environment variables' }
                [PSCustomObject]@{ Command = 'cgrenv show <name>';                    Info = 'Display a specific environment variable' }
                [PSCustomObject]@{ Command = 'cgrenv addsession <name> <value>';      Info = 'Set an env variable for the current session' }
                [PSCustomObject]@{ Command = 'cgrenv addpermanent <name> <value>';    Info = 'Set an env variable permanently' }
            )
        }
        [PSCustomObject]@{
            Name        = 'll'
            Category    = 'builtin'
            Description = 'Enhanced directory listing using eza (long format)'
            Usage       = @(
                [PSCustomObject]@{ Command = 'll [path]'; Info = 'List directory contents with icons, git status, and details' }
            )
        }
        [PSCustomObject]@{
            Name        = 'mkcd'
            Category    = 'builtin'
            Description = 'Create a directory and cd into it in one step'
            Usage       = @(
                [PSCustomObject]@{ Command = 'mkcd <dir>'; Info = 'Create the directory (including parents) and change into it' }
            )
        }
        [PSCustomObject]@{
            Name        = 'open'
            Category    = 'builtin'
            Description = 'Open a path in the system file explorer (Explorer/Finder/xdg-open)'
            Usage       = @(
                [PSCustomObject]@{ Command = 'open [path]'; Info = 'Open the given path (defaults to current directory)' }
            )
        }
        [PSCustomObject]@{
            Name        = 'which'
            Category    = 'builtin'
            Description = 'Find the location of a command (works with aliases, functions, and executables)'
            Usage       = @(
                [PSCustomObject]@{ Command = 'which <command>'; Info = 'Show the source/path of the command' }
            )
        }
        [PSCustomObject]@{
            Name        = 'cgrman'
            Category    = 'builtin'
            Description = 'Interactive browser for Congruens commands and tool definitions'
            Usage       = @(
                [PSCustomObject]@{ Command = 'cgrman'; Info = 'Open this manual' }
            )
        }
        [PSCustomObject]@{
            Name        = 'motd'
            Category    = 'builtin'
            Description = 'Display the Congruens Message of the Day with system info'
            Usage       = @(
                [PSCustomObject]@{ Command = 'motd';                Info = 'Show welcome banner and fastfetch output' }
                [PSCustomObject]@{ Command = 'motd -SkipFastfetch'; Info = 'Show banner only, skip system info' }
            )
        }
    )

    # --- External tool definitions from tools/*.json ---
    $congruensRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    $toolsPath = Join-Path $congruensRoot "tools"

    $externalTools = @()
    if (Test-Path $toolsPath) {
        $toolFiles = Get-ChildItem -Path $toolsPath -Filter "*.json" | Sort-Object Name
        foreach ($file in $toolFiles) {
            try {
                $tool = Get-Content $file.FullName -Raw | ConvertFrom-Json
                $externalTools += [PSCustomObject]@{
                    Name        = $tool.name
                    Category    = 'external'
                    Description = $tool.description
                    Homepage    = $tool.homepage
                    Verify      = $tool.verify
                    FileName    = $file.BaseName
                    Install     = $tool.install
                }
            }
            catch {
                Write-Warning "Failed to parse $($file.Name): $_"
            }
        }
    }

    # Combine: built-in commands first, then external tools
    $allEntries = @() + $builtinCommands + $externalTools

    if ($allEntries.Count -eq 0) {
        Write-Error "No commands or tool definitions found"
        return
    }

    $currentIndex = 0
    $running = $true

    # Function to display a built-in command page
    function Show-Builtin {
        param([PSCustomObject]$Entry, [int]$Index, [int]$Total)
        
        Clear-Host
        Write-Host ""
        Write-Host "  CONGRUENS MANUAL" -ForegroundColor Cyan
        Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
        
        Write-Host "  $($Entry.Name)" -ForegroundColor Yellow -NoNewline
        Write-Host "  ($($Index + 1)/$Total)" -ForegroundColor DarkGray -NoNewline
        Write-Host "  [built-in]" -ForegroundColor Green
        Write-Host ""
        Write-Host "  $($Entry.Description)" -ForegroundColor White
        Write-Host ""
        
        Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  Usage:" -ForegroundColor DarkGray
        Write-Host ""
        
        foreach ($u in $Entry.Usage) {
            Write-Host "    $($u.Command)" -ForegroundColor Cyan
            Write-Host "      $($u.Info)" -ForegroundColor Gray
            Write-Host ""
        }
        
        Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  [<-] Previous  [->] Next  [q/Esc] Quit" -ForegroundColor DarkGray
        Write-Host ""
    }

    # Function to display an external tool page
    function Show-ExternalTool {
        param([PSCustomObject]$Entry, [int]$Index, [int]$Total)
        
        Clear-Host
        Write-Host ""
        Write-Host "  CONGRUENS MANUAL" -ForegroundColor Cyan
        Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
        
        Write-Host "  $($Entry.Name)" -ForegroundColor Yellow -NoNewline
        Write-Host "  ($($Index + 1)/$Total)" -ForegroundColor DarkGray -NoNewline
        Write-Host "  [external tool]" -ForegroundColor Magenta
        Write-Host ""
        Write-Host "  $($Entry.Description)" -ForegroundColor White
        Write-Host ""
        
        if ($Entry.Homepage) {
            Write-Host "  Homepage: " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($Entry.Homepage)" -ForegroundColor Blue
        }
        
        if ($Entry.Verify) {
            Write-Host "  Verify:   " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($Entry.Verify)" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  Install methods:" -ForegroundColor DarkGray
        Write-Host ""
        
        if ($Entry.Install.windows) {
            Write-Host "    Windows:" -ForegroundColor Magenta
            if ($Entry.Install.windows.winget) {
                Write-Host "      winget: " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($Entry.Install.windows.winget)" -ForegroundColor White
            }
            if ($Entry.Install.windows.choco) {
                Write-Host "      choco:  " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($Entry.Install.windows.choco)" -ForegroundColor White
            }
        }
        
        if ($Entry.Install.macos) {
            Write-Host "    macOS:" -ForegroundColor Magenta
            if ($Entry.Install.macos.brew) {
                Write-Host "      brew:   " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($Entry.Install.macos.brew)" -ForegroundColor White
            }
        }
        
        if ($Entry.Install.linux) {
            Write-Host "    Linux:" -ForegroundColor Magenta
            if ($Entry.Install.linux.apt) {
                Write-Host "      apt:    " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($Entry.Install.linux.apt)" -ForegroundColor White
            }
            if ($Entry.Install.linux.dnf) {
                Write-Host "      dnf:    " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($Entry.Install.linux.dnf)" -ForegroundColor White
            }
            if ($Entry.Install.linux.pacman) {
                Write-Host "      pacman: " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($Entry.Install.linux.pacman)" -ForegroundColor White
            }
        }
        
        Write-Host ""
        Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  [<-] Previous  [->] Next  [q/Esc] Quit" -ForegroundColor DarkGray
        Write-Host ""
    }

    # Render the current entry
    function Show-Entry {
        param([int]$Index)
        $entry = $allEntries[$Index]
        $total = $allEntries.Count
        if ($entry.Category -eq 'builtin') {
            Show-Builtin -Entry $entry -Index $Index -Total $total
        }
        else {
            Show-ExternalTool -Entry $entry -Index $Index -Total $total
        }
    }

    # Initial display
    Show-Entry -Index $currentIndex

    # Main loop
    while ($running) {
        $key = [Console]::ReadKey($true)
        
        switch ($key.Key) {
            'LeftArrow' {
                if ($currentIndex -gt 0) {
                    $currentIndex--
                }
                elseif ($allEntries.Count -gt 1) {
                    $currentIndex = $allEntries.Count - 1
                }
                Show-Entry -Index $currentIndex
            }
            'RightArrow' {
                if ($currentIndex -lt $allEntries.Count - 1) {
                    $currentIndex++
                }
                elseif ($allEntries.Count -gt 1) {
                    $currentIndex = 0
                }
                Show-Entry -Index $currentIndex
            }
            'Home' {
                $currentIndex = 0
                Show-Entry -Index $currentIndex
            }
            'End' {
                $currentIndex = $allEntries.Count - 1
                Show-Entry -Index $currentIndex
            }
            'Escape' {
                $running = $false
            }
            'Q' {
                $running = $false
            }
        }
    }

    Clear-Host
}

# Alias for convenience
function cgrman {
    <#
    .SYNOPSIS
        Alias for Show-CongruensManual - Congruens Manual.
    #>
    [CmdletBinding()]
    param()

    Show-CongruensManual
}

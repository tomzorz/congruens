<#
.SYNOPSIS
    Interactive browser for Congruens tool definitions.

.DESCRIPTION
    Displays tool definitions from the tools/ directory in an interactive viewer.
    Use left/right arrow keys to navigate between tools, and 'q' or Escape to quit.
#>

function Show-CongruensManual {
    <#
    .SYNOPSIS
        Browse tool definitions interactively.
    
    .DESCRIPTION
        Displays tools from the tools/*.json directory. Navigate with arrow keys.
    
    .EXAMPLE
        Show-CongruensManual
        
        Opens the interactive tool browser.
    
    .EXAMPLE
        cgrman
        
        Same as Show-CongruensManual.
    #>
    [CmdletBinding()]
    param()

    # Find tools directory
    $dotfilesPath = Join-Path $HOME "dotfiles"
    $toolsPath = Join-Path $dotfilesPath "tools"

    if (-not (Test-Path $toolsPath)) {
        Write-Error "Tools directory not found at $toolsPath"
        return
    }

    # Load all tool definitions
    $toolFiles = Get-ChildItem -Path $toolsPath -Filter "*.json" | Sort-Object Name
    if ($toolFiles.Count -eq 0) {
        Write-Error "No tool definitions found in $toolsPath"
        return
    }

    $tools = @()
    foreach ($file in $toolFiles) {
        try {
            $tool = Get-Content $file.FullName -Raw | ConvertFrom-Json
            $tools += [PSCustomObject]@{
                Name        = $tool.name
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

    if ($tools.Count -eq 0) {
        Write-Error "No valid tool definitions found"
        return
    }

    $currentIndex = 0
    $running = $true

    # Function to display current tool
    function Show-Tool {
        param([int]$Index)
        
        Clear-Host
        $tool = $tools[$Index]
        $total = $tools.Count
        
        # Header
        Write-Host ""
        Write-Host "  CONGRUENS MANUAL" -ForegroundColor Cyan
        Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host ""
        
        # Tool info
        Write-Host "  $($tool.Name)" -ForegroundColor Yellow -NoNewline
        Write-Host "  ($($Index + 1)/$total)" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "  $($tool.Description)" -ForegroundColor White
        Write-Host ""
        
        if ($tool.Homepage) {
            Write-Host "  Homepage: " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($tool.Homepage)" -ForegroundColor Blue
        }
        
        if ($tool.Verify) {
            Write-Host "  Verify:   " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($tool.Verify)" -ForegroundColor Gray
        }
        
        Write-Host ""
        Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        
        # Install methods
        Write-Host "  Install methods:" -ForegroundColor DarkGray
        Write-Host ""
        
        if ($tool.Install.windows) {
            Write-Host "    Windows:" -ForegroundColor Magenta
            if ($tool.Install.windows.winget) {
                Write-Host "      winget: " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($tool.Install.windows.winget)" -ForegroundColor White
            }
            if ($tool.Install.windows.choco) {
                Write-Host "      choco:  " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($tool.Install.windows.choco)" -ForegroundColor White
            }
        }
        
        if ($tool.Install.macos) {
            Write-Host "    macOS:" -ForegroundColor Magenta
            if ($tool.Install.macos.brew) {
                Write-Host "      brew:   " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($tool.Install.macos.brew)" -ForegroundColor White
            }
        }
        
        if ($tool.Install.linux) {
            Write-Host "    Linux:" -ForegroundColor Magenta
            if ($tool.Install.linux.apt) {
                Write-Host "      apt:    " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($tool.Install.linux.apt)" -ForegroundColor White
            }
            if ($tool.Install.linux.dnf) {
                Write-Host "      dnf:    " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($tool.Install.linux.dnf)" -ForegroundColor White
            }
            if ($tool.Install.linux.pacman) {
                Write-Host "      pacman: " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($tool.Install.linux.pacman)" -ForegroundColor White
            }
        }
        
        Write-Host ""
        Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  [←] Previous  [→] Next  [q/Esc] Quit" -ForegroundColor DarkGray
        Write-Host ""
    }

    # Initial display
    Show-Tool -Index $currentIndex

    # Main loop
    while ($running) {
        $key = [Console]::ReadKey($true)
        
        switch ($key.Key) {
            'LeftArrow' {
                if ($currentIndex -gt 0) {
                    $currentIndex--
                    Show-Tool -Index $currentIndex
                }
                elseif ($tools.Count -gt 1) {
                    # Wrap to end
                    $currentIndex = $tools.Count - 1
                    Show-Tool -Index $currentIndex
                }
            }
            'RightArrow' {
                if ($currentIndex -lt $tools.Count - 1) {
                    $currentIndex++
                    Show-Tool -Index $currentIndex
                }
                elseif ($tools.Count -gt 1) {
                    # Wrap to beginning
                    $currentIndex = 0
                    Show-Tool -Index $currentIndex
                }
            }
            'Home' {
                $currentIndex = 0
                Show-Tool -Index $currentIndex
            }
            'End' {
                $currentIndex = $tools.Count - 1
                Show-Tool -Index $currentIndex
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

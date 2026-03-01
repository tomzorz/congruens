<#
.SYNOPSIS
    Interactive browser for Congruens commands and tool definitions.

.DESCRIPTION
    Dynamically discovers built-in commands from builtins/*.json and external
    tools from tools/*.json. Use subcommands to browse each category.
#>

function Show-CongruensManual {
    <#
    .SYNOPSIS
        Browse built-in commands and tool definitions interactively.

    .DESCRIPTION
        With no arguments, shows available subcommands.
        Use 'builtins' to browse built-in Congruens commands.
        Use 'tools' to browse external tool definitions.
        Both categories are discovered dynamically from JSON files.

    .PARAMETER Section
        The section to browse: builtins or tools.

    .EXAMPLE
        Show-CongruensManual

        Shows available subcommands.

    .EXAMPLE
        cgrman builtins

        Opens the interactive browser for built-in commands.

    .EXAMPLE
        cgrman tools

        Opens the interactive browser for external tools.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('builtins', 'tools')]
        [string]$Section
    )

    $congruensRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

    if (-not $Section) {
        Show-ManualHelp -CongruensRoot $congruensRoot
        return
    }

    switch ($Section) {
        'builtins' { Show-BuiltinBrowser -CongruensRoot $congruensRoot }
        'tools' { Show-ToolBrowser -CongruensRoot $congruensRoot }
    }
}

# --- Private: help screen when no subcommand is given ---

function Show-ManualHelp {
    param([string]$CongruensRoot)

    $builtinsPath = Join-Path $CongruensRoot "builtins"
    $toolsPath = Join-Path $CongruensRoot "tools"

    $builtinCount = 0
    if (Test-Path $builtinsPath) {
        $builtinCount = (Get-ChildItem -Path $builtinsPath -Filter "*.json" | Measure-Object).Count
    }
    $toolCount = 0
    if (Test-Path $toolsPath) {
        $toolCount = (Get-ChildItem -Path $toolsPath -Filter "*.json" | Measure-Object).Count
    }

    Write-Host ""
    Write-Host "  CONGRUENS MANUAL" -ForegroundColor Cyan
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
    Write-Host "  Usage:" -ForegroundColor White
    Write-Host "    cgrman builtins" -ForegroundColor Yellow -NoNewline
    Write-Host "    Browse built-in commands ($builtinCount)" -ForegroundColor Gray
    Write-Host "    cgrman tools" -ForegroundColor Yellow -NoNewline
    Write-Host "       Browse external tools ($toolCount)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray

    # Quick summary of builtins
    if ($builtinCount -gt 0) {
        Write-Host ""
        Write-Host "  Built-in commands:" -ForegroundColor White
        $builtinFiles = Get-ChildItem -Path $builtinsPath -Filter "*.json" | Sort-Object Name
        foreach ($file in $builtinFiles) {
            try {
                $cmd = Get-Content $file.FullName -Raw | ConvertFrom-Json
                Write-Host "    $($cmd.name)" -ForegroundColor Yellow -NoNewline
                $padding = ' ' * [Math]::Max(1, 14 - $cmd.name.Length)
                Write-Host "$padding$($cmd.description)" -ForegroundColor Gray
            }
            catch {
                Write-Warning "  Failed to parse $($file.Name): $_"
            }
        }
    }

    # Quick summary of tools (just count, don't list all 38)
    if ($toolCount -gt 0) {
        Write-Host ""
        Write-Host "  External tools:" -ForegroundColor White
        Write-Host "    $toolCount tools configured" -ForegroundColor Gray -NoNewline
        Write-Host " (run " -ForegroundColor DarkGray -NoNewline
        Write-Host "cgrman tools" -ForegroundColor Yellow -NoNewline
        Write-Host " to browse)" -ForegroundColor DarkGray
    }

    Write-Host ""
}

# --- Private: interactive TUI for built-in commands ---

function Show-BuiltinBrowser {
    param([string]$CongruensRoot)

    $builtinsPath = Join-Path $CongruensRoot "builtins"
    $entries = @()

    if (Test-Path $builtinsPath) {
        $files = Get-ChildItem -Path $builtinsPath -Filter "*.json" | Sort-Object Name
        foreach ($file in $files) {
            try {
                $cmd = Get-Content $file.FullName -Raw | ConvertFrom-Json
                $usage = @()
                foreach ($u in $cmd.usage) {
                    $usage += [PSCustomObject]@{ Command = $u.command; Info = $u.info }
                }
                $entries += [PSCustomObject]@{
                    Name        = $cmd.name
                    Description = $cmd.description
                    Usage       = $usage
                }
            }
            catch {
                Write-Warning "Failed to parse $($file.Name): $_"
            }
        }
    }

    if ($entries.Count -eq 0) {
        Write-Error "No built-in command definitions found in builtins/"
        return
    }

    Start-InteractiveBrowser -Entries $entries -Category 'builtin'
}

# --- Private: interactive TUI for external tools ---

function Show-ToolBrowser {
    param([string]$CongruensRoot)

    $toolsPath = Join-Path $CongruensRoot "tools"
    $entries = @()

    if (Test-Path $toolsPath) {
        $files = Get-ChildItem -Path $toolsPath -Filter "*.json" | Sort-Object Name
        foreach ($file in $files) {
            try {
                $tool = Get-Content $file.FullName -Raw | ConvertFrom-Json
                $entries += [PSCustomObject]@{
                    Name        = $tool.name
                    Description = $tool.description
                    Homepage    = $tool.homepage
                    Verify      = $tool.verify
                    Install     = $tool.install
                }
            }
            catch {
                Write-Warning "Failed to parse $($file.Name): $_"
            }
        }
    }

    if ($entries.Count -eq 0) {
        Write-Error "No tool definitions found in tools/"
        return
    }

    Start-InteractiveBrowser -Entries $entries -Category 'external'
}

# --- Private: shared interactive TUI ---

function Start-InteractiveBrowser {
    param(
        [PSCustomObject[]]$Entries,
        [string]$Category
    )

    $currentIndex = 0
    $running = $true

    # Render the current entry
    Render-Entry -Entries $Entries -Index $currentIndex -Category $Category

    while ($running) {
        $key = [Console]::ReadKey($true)

        switch ($key.Key) {
            'LeftArrow' {
                if ($currentIndex -gt 0) { $currentIndex-- }
                elseif ($Entries.Count -gt 1) { $currentIndex = $Entries.Count - 1 }
                Render-Entry -Entries $Entries -Index $currentIndex -Category $Category
            }
            'RightArrow' {
                if ($currentIndex -lt $Entries.Count - 1) { $currentIndex++ }
                elseif ($Entries.Count -gt 1) { $currentIndex = 0 }
                Render-Entry -Entries $Entries -Index $currentIndex -Category $Category
            }
            'Home' {
                $currentIndex = 0
                Render-Entry -Entries $Entries -Index $currentIndex -Category $Category
            }
            'End' {
                $currentIndex = $Entries.Count - 1
                Render-Entry -Entries $Entries -Index $currentIndex -Category $Category
            }
            'Escape' { $running = $false }
            'Q' { $running = $false }
        }
    }

    Clear-Host
}

# --- Private: render a single entry page ---

function Render-Entry {
    param(
        [PSCustomObject[]]$Entries,
        [int]$Index,
        [string]$Category
    )

    $entry = $Entries[$Index]
    $total = $Entries.Count

    Clear-Host
    Write-Host ""
    Write-Host "  CONGRUENS MANUAL" -ForegroundColor Cyan
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    Write-Host "  $($entry.Name)" -ForegroundColor Yellow -NoNewline
    Write-Host "  ($($Index + 1)/$total)" -ForegroundColor DarkGray -NoNewline
    if ($Category -eq 'builtin') {
        Write-Host "  [built-in]" -ForegroundColor Green
    }
    else {
        Write-Host "  [external tool]" -ForegroundColor Magenta
    }

    Write-Host ""
    Write-Host "  $($entry.Description)" -ForegroundColor White
    Write-Host ""

    if ($Category -eq 'builtin') {
        Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  Usage:" -ForegroundColor DarkGray
        Write-Host ""

        foreach ($u in $entry.Usage) {
            Write-Host "    $($u.Command)" -ForegroundColor Cyan
            Write-Host "      $($u.Info)" -ForegroundColor Gray
            Write-Host ""
        }
    }
    else {
        if ($entry.Homepage) {
            Write-Host "  Homepage: " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($entry.Homepage)" -ForegroundColor Blue
        }

        if ($entry.Verify) {
            Write-Host "  Verify:   " -ForegroundColor DarkGray -NoNewline
            Write-Host "$($entry.Verify)" -ForegroundColor Gray
        }

        Write-Host ""
        Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
        Write-Host "  Install methods:" -ForegroundColor DarkGray
        Write-Host ""

        if ($entry.Install.windows) {
            Write-Host "    Windows:" -ForegroundColor Magenta
            if ($entry.Install.windows.winget) {
                Write-Host "      winget: " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($entry.Install.windows.winget)" -ForegroundColor White
            }
            if ($entry.Install.windows.choco) {
                Write-Host "      choco:  " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($entry.Install.windows.choco)" -ForegroundColor White
            }
        }

        if ($entry.Install.macos) {
            Write-Host "    macOS:" -ForegroundColor Magenta
            if ($entry.Install.macos.brew) {
                Write-Host "      brew:   " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($entry.Install.macos.brew)" -ForegroundColor White
            }
        }

        if ($entry.Install.linux) {
            Write-Host "    Linux:" -ForegroundColor Magenta
            if ($entry.Install.linux.apt) {
                Write-Host "      apt:    " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($entry.Install.linux.apt)" -ForegroundColor White
            }
            if ($entry.Install.linux.dnf) {
                Write-Host "      dnf:    " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($entry.Install.linux.dnf)" -ForegroundColor White
            }
            if ($entry.Install.linux.pacman) {
                Write-Host "      pacman: " -NoNewline -ForegroundColor DarkGray
                Write-Host "$($entry.Install.linux.pacman)" -ForegroundColor White
            }
        }
    }

    Write-Host ""
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  [<-] Previous  [->] Next  [Home] First  [End] Last  [q/Esc] Quit" -ForegroundColor DarkGray
    Write-Host ""
}

# --- Wrapper function ---

function cgrman {
    <#
    .SYNOPSIS
        Congruens Manual - browse built-in commands and external tools.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet('builtins', 'tools')]
        [string]$Section
    )

    Show-CongruensManual @PSBoundParameters
}

# --- Tab completion for the Section parameter ---

$_cgrmanCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    @('builtins', 'tools') |
        Where-Object { $_ -like "$wordToComplete*" } |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_,
                $_,
                'ParameterValue',
                $_
            )
        }
}

Register-ArgumentCompleter -CommandName 'Show-CongruensManual' -ParameterName 'Section' -ScriptBlock $_cgrmanCompleter
Register-ArgumentCompleter -CommandName 'cgrman' -ParameterName 'Section' -ScriptBlock $_cgrmanCompleter

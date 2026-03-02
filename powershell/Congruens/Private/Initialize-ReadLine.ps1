# PSReadLine configuration
# Replaces the need for clink by bringing bash-like editing, tab completion,
# history search, and predictive IntelliSense to PowerShell natively.

function Initialize-ReadLine {
    $module = Get-Module PSReadLine -ErrorAction SilentlyContinue
    if (-not $module) {
        Import-Module PSReadLine -ErrorAction SilentlyContinue
        $module = Get-Module PSReadLine -ErrorAction SilentlyContinue
    }
    if (-not $module) return

    # -- Editing mode ----------------------------------------------------------
    # Emacs mode: Ctrl+A/E for home/end, Ctrl+K to kill line, etc.
    # This matches bash/clink defaults so muscle memory transfers.
    Set-PSReadLineOption -EditMode Emacs

    # -- Tab completion --------------------------------------------------------
    # MenuComplete: inline cycling with an interactive menu on ambiguous matches.
    # This is the clink behavior that made people want it in PowerShell.
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key Shift+Tab -Function TabCompleteNext

    # -- History search --------------------------------------------------------
    # Type partial text, press Up/Down to cycle through matching history entries.
    # Clink's crown jewel, now native.
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # Incremental search with Ctrl+R / Ctrl+S (bash standard)
    Set-PSReadLineKeyHandler -Key Ctrl+r -Function ReverseSearchHistory

    # -- History options -------------------------------------------------------
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd
    Set-PSReadLineOption -MaximumHistoryCount 10000

    # Don't store duplicate consecutive commands or commands starting with a space
    Set-PSReadLineOption -HistoryNoDuplicates
    Set-PSReadLineOption -AddToHistoryHandler {
        param($command)
        if ($command -match '^\s') { return $false }
        return $true
    }

    # -- Predictive IntelliSense -----------------------------------------------
    # Show suggestions from history as you type (like fish/clink auto-suggest).
    # ListView gives a dropdown; HistoryAndPlugin uses command history + any
    # installed prediction plugins.
    $psrlVersion = $module.Version
    if ($psrlVersion -ge [version]'2.2.0') {
        Set-PSReadLineOption -PredictionSource HistoryAndPlugin
        Set-PSReadLineOption -PredictionViewStyle ListView
    }
    elseif ($psrlVersion -ge [version]'2.1.0') {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle InlineView
    }

    # -- Colors ----------------------------------------------------------------
    # Muted prediction color so it doesn't fight with the actual input.
    Set-PSReadLineOption -Colors @{
        InlinePrediction = [ConsoleColor]::DarkGray
    }

    # -- Quality of life -------------------------------------------------------
    # Show matching brace/bracket/paren when cursor is on one
    Set-PSReadLineOption -ShowToolTips

    # Ctrl+D to exit (bash habit)
    Set-PSReadLineKeyHandler -Key Ctrl+d -Function DeleteCharOrExit

    # Smart quotes/parens: typing an opening bracket auto-inserts the closing one
    Set-PSReadLineKeyHandler -Key '"', "'" -BriefDescription SmartInsertQuote -ScriptBlock {
        param($key, $arg)
        $line = $null; $cursor = $null
        [Microsoft.PowerShell.PSConsoleReadLine]::GetBufferState([ref]$line, [ref]$cursor)

        $quote = $key.KeyChar
        if ($cursor -lt $line.Length -and $line[$cursor] -eq $quote) {
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        }
        else {
            [Microsoft.PowerShell.PSConsoleReadLine]::Insert("$quote$quote")
            [Microsoft.PowerShell.PSConsoleReadLine]::SetCursorPosition($cursor + 1)
        }
    }
}

<#
.SYNOPSIS
    Directory bookmarking with aliases (jump, setjump, deljump).

.DESCRIPTION
    Bookmark directories with human-friendly aliases and jump to them instantly.
    Bookmarks are stored in ~/.jumpmap.json and persist across sessions.
    All alias names get tab-completion.
#>

# --- Private helpers (file-scoped, not exported) ---

function Get-JumpMapPath {
    Join-Path ([Environment]::GetFolderPath('UserProfile')) '.jumpmap.json'
}

function Read-JumpMap {
    $path = Get-JumpMapPath
    if (Test-Path $path) {
        $raw = Get-Content -Path $path -Raw -ErrorAction SilentlyContinue
        if ($raw) {
            try { return $raw | ConvertFrom-Json -AsHashtable }
            catch { Write-Warning "Corrupt jumpmap at $path, starting fresh."; return @{} }
        }
    }
    return @{}
}

function Write-JumpMap {
    param([hashtable]$Map)
    $path = Get-JumpMapPath
    $Map | ConvertTo-Json -Depth 1 | Set-Content -Path $path -Encoding UTF8
}

# --- Public functions ---

function Invoke-JumpCommand {
    <#
    .SYNOPSIS
        Jump to a bookmarked directory by alias.

    .DESCRIPTION
        Changes the current working directory to the path stored under the
        given alias in ~/.jumpmap.json. Use 'setjump' to create bookmarks
        and 'deljump' to remove them.

        When called without an alias, lists all saved bookmarks.

    .PARAMETER Alias
        The bookmark alias to jump to. Tab-completion provides all known aliases.

    .EXAMPLE
        jump work

        Changes directory to wherever 'work' points.

    .EXAMPLE
        jump

        Lists all saved bookmarks.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Alias
    )

    $map = Read-JumpMap

    if (-not $Alias) {
        if ($map.Count -eq 0) {
            Write-Output "No bookmarks saved. Use 'setjump <alias>' to add one."
            return
        }
        $maxLen = ($map.Keys | Measure-Object -Property Length -Maximum).Maximum
        foreach ($key in $map.Keys | Sort-Object) {
            $exists = Test-Path $map[$key] -PathType Container
            $status = if ($exists) { ' ' } else { '!' }
            Write-Output ("{0} {1}  ->  {2}" -f $status, $key.PadRight($maxLen), $map[$key])
        }
        return
    }

    if (-not $map.ContainsKey($Alias)) {
        Write-Error "No bookmark named '$Alias'. Use 'jump' to list bookmarks or 'setjump $Alias' to create one."
        return
    }

    $target = $map[$Alias]
    if (-not (Test-Path $target -PathType Container)) {
        Write-Error "Bookmark '$Alias' points to '$target' which no longer exists. Use 'deljump $Alias' to remove it."
        return
    }

    Set-Location -Path $target
}

function Set-JumpAlias {
    <#
    .SYNOPSIS
        Bookmark the current directory with an alias.

    .DESCRIPTION
        Saves the current working directory to ~/.jumpmap.json under the given
        alias name. If the alias already exists, it is overwritten with a warning.

    .PARAMETER Alias
        The name to give this bookmark.

    .EXAMPLE
        setjump work

        Bookmarks the current directory as 'work'.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Alias
    )

    $map = Read-JumpMap
    $dir = (Get-Location).Path

    if ($map.ContainsKey($Alias)) {
        $old = $map[$Alias]
        if ($old -eq $dir) {
            Write-Output "Bookmark '$Alias' already points here."
            return
        }
        Write-Warning "Overwriting bookmark '$Alias': $old -> $dir"
    }

    $map[$Alias] = $dir
    Write-JumpMap -Map $map
    Write-Output "Bookmarked '$Alias' -> $dir"
}

function Remove-JumpAlias {
    <#
    .SYNOPSIS
        Remove a directory bookmark.

    .DESCRIPTION
        Deletes the given alias from ~/.jumpmap.json.

    .PARAMETER Alias
        The bookmark alias to remove. Tab-completion provides all known aliases.

    .EXAMPLE
        deljump work

        Removes the 'work' bookmark.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Alias
    )

    $map = Read-JumpMap

    if (-not $map.ContainsKey($Alias)) {
        Write-Error "No bookmark named '$Alias'. Use 'jump' to list bookmarks."
        return
    }

    $removed = $map[$Alias]
    $map.Remove($Alias)
    Write-JumpMap -Map $map
    Write-Output "Removed bookmark '$Alias' (was -> $removed)"
}

# --- Short-name wrappers (exported as functions so parameter attrs survive) ---

function jump {
    <#
    .SYNOPSIS
        Alias for Invoke-JumpCommand.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Alias
    )
    Invoke-JumpCommand @PSBoundParameters
}

function setjump {
    <#
    .SYNOPSIS
        Alias for Set-JumpAlias.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Alias
    )
    Set-JumpAlias @PSBoundParameters
}

function deljump {
    <#
    .SYNOPSIS
        Alias for Remove-JumpAlias.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string]$Alias
    )
    Remove-JumpAlias @PSBoundParameters
}

# --- Tab completion for the Alias parameter ---
# Reads ~/.jumpmap.json and offers alias names. Works for jump, deljump, and
# setjump (setjump completions are useful to see what's taken).

$_jumpCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $mapPath = Join-Path ([Environment]::GetFolderPath('UserProfile')) '.jumpmap.json'
    if (-not (Test-Path $mapPath)) { return }

    $raw = Get-Content -Path $mapPath -Raw -ErrorAction SilentlyContinue
    if (-not $raw) { return }

    try { $map = $raw | ConvertFrom-Json -AsHashtable }
    catch { return }

    $map.GetEnumerator() |
        Where-Object { $_.Key -like "$wordToComplete*" } |
        Sort-Object Key |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_.Key,          # completionText
                $_.Key,          # listItemText
                'ParameterValue', # resultType
                $_.Value          # toolTip (shows the path on hover)
            )
        }
}

# Register the completer for all commands that take the Alias parameter.
# This covers both the formal names and the short-name wrappers.
$_jumpCommandNames = @(
    'Invoke-JumpCommand', 'jump',
    'Remove-JumpAlias', 'deljump',
    'Set-JumpAlias', 'setjump'
)
foreach ($cmd in $_jumpCommandNames) {
    Register-ArgumentCompleter -CommandName $cmd -ParameterName 'Alias' -ScriptBlock $_jumpCompleter
}

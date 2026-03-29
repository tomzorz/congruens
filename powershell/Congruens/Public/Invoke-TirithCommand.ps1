<#
.SYNOPSIS
    PowerShell wrapper for tirith, the terminal security guard.

.DESCRIPTION
    Provides tab-completion for tirith subcommands and a convenient short-name
    alias. Tirith detects homograph attacks, pipe-to-shell exploits, ANSI
    injection, credential leaks, and other terminal-based threats.
#>

function Invoke-TirithCommand {
    <#
    .SYNOPSIS
        Invoke tirith with a subcommand.

    .DESCRIPTION
        Thin wrapper around tirith that provides tab-completion for subcommands
        and passes all remaining arguments through verbatim.

    .PARAMETER Subcommand
        The tirith subcommand to run: check, paste, score, diff, run, scan,
        receipt, why, fetch, checkpoint, gateway, setup, audit, init, doctor.

    .PARAMETER Arguments
        Additional arguments passed to tirith.

    .EXAMPLE
        tirith-check check -- curl https://example.com | bash

        Analyze a command without executing it.

    .EXAMPLE
        tirith-check scan .

        Scan the current directory for hidden content.

    .EXAMPLE
        tirith-check score https://example.com

        Show trust-signal breakdown for a URL.

    .EXAMPLE
        tirith-check doctor

        Run a diagnostic health check.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet(
            'check', 'paste', 'score', 'diff', 'run', 'scan',
            'receipt', 'why', 'fetch', 'checkpoint', 'gateway',
            'setup', 'audit', 'init', 'doctor'
        )]
        [string]$Subcommand,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    $tirithCmd = Get-Command tirith -ErrorAction SilentlyContinue
    if (-not $tirithCmd) {
        Write-Error "tirith is not installed. Install it via 'cgrinstall' or visit https://github.com/sheeki03/tirith"
        return
    }

    if ($Subcommand) {
        & tirith $Subcommand @Arguments
    }
    else {
        & tirith @Arguments
    }
}

function tirith-check {
    <#
    .SYNOPSIS
        Alias for Invoke-TirithCommand - terminal security guard.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [ValidateSet(
            'check', 'paste', 'score', 'diff', 'run', 'scan',
            'receipt', 'why', 'fetch', 'checkpoint', 'gateway',
            'setup', 'audit', 'init', 'doctor'
        )]
        [string]$Subcommand,

        [Parameter(Position = 1, ValueFromRemainingArguments)]
        [string[]]$Arguments
    )
    Invoke-TirithCommand @PSBoundParameters
}

# Tab completion for both the formal and short names
$tirithSubcommands = @(
    @{ Text = 'check';      Tooltip = 'Analyze a command without executing it' }
    @{ Text = 'paste';      Tooltip = 'Analyze pasted content for threats' }
    @{ Text = 'score';      Tooltip = 'Trust-signal breakdown for a URL' }
    @{ Text = 'diff';       Tooltip = 'Byte-level diff showing suspicious characters' }
    @{ Text = 'run';        Tooltip = 'Safe replacement for curl | bash' }
    @{ Text = 'scan';       Tooltip = 'Scan files/directories for hidden content' }
    @{ Text = 'receipt';    Tooltip = 'Track and verify install receipts' }
    @{ Text = 'why';        Tooltip = 'Explain the last triggered rule' }
    @{ Text = 'fetch';      Tooltip = 'Detect server-side cloaking' }
    @{ Text = 'checkpoint'; Tooltip = 'Snapshot files before risky operations' }
    @{ Text = 'gateway';    Tooltip = 'MCP gateway proxy for AI agents' }
    @{ Text = 'setup';      Tooltip = 'One-command setup for AI coding tools' }
    @{ Text = 'audit';      Tooltip = 'Audit log management' }
    @{ Text = 'init';       Tooltip = 'Print shell hook for integration' }
    @{ Text = 'doctor';     Tooltip = 'Run a diagnostic health check' }
)

$tirithCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    $tirithSubcommands | Where-Object { $_.Text -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_.Text, $_.Text, 'ParameterValue', $_.Tooltip)
    }
}

Register-ArgumentCompleter -CommandName 'Invoke-TirithCommand' -ParameterName 'Subcommand' -ScriptBlock $tirithCompleter
Register-ArgumentCompleter -CommandName 'tirith-check' -ParameterName 'Subcommand' -ScriptBlock $tirithCompleter

<#
.SYNOPSIS
    Install and update self-managed tools from GitHub releases.

.DESCRIPTION
    Some tools ship releases far faster than winget/brew/apt can follow, and a
    few (yt-dlp is the notable one) refuse to self-update at all when they
    detect a package-manager install. For those, congruens owns the binary
    directly: it downloads the release asset into ~/.congruens/bin, which
    profile.ps1 prepends to PATH, and then either lets the tool update itself
    or re-downloads the asset.

    Tools opt in by declaring a "github" block in their tools/*.json install
    section. Only bare single-file assets are supported - archives are out of
    scope on purpose, because the tools that need same-day updates all ship
    plain binaries.

    No GitHub API calls are made. Everything goes through the
    /releases/latest/download/ redirect, so there is no 60-request unauthorised
    rate limit to trip over.
#>

# --- Private: where congruens-owned binaries live ---

function Get-CongruensBinDir {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return (Join-Path (Join-Path $HOME '.congruens') 'bin')
}

# --- Private: repo tools/ directory ---

function Get-CongruensToolsDir {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $congruensRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))
    return (Join-Path $congruensRoot 'tools')
}

# --- Private: current processor architecture ---

function Get-CongruensArch {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $arch = [System.Runtime.InteropServices.RuntimeInformation]::OSArchitecture
    if ($arch -eq [System.Runtime.InteropServices.Architecture]::Arm64) {
        return 'arm64'
    }
    return 'x64'
}

# --- Private: load every tool definition that opts into the github method ---

function Get-CongruensGitHubTool {
    <#
    .SYNOPSIS
        Return tool definitions that declare a github install block for this platform.
    #>
    [CmdletBinding()]
    param(
        [string]$Name
    )

    $toolsDir = Get-CongruensToolsDir
    if (-not (Test-Path $toolsDir)) {
        Write-Error "Tools directory not found at $toolsDir"
        return
    }

    $platform = Get-Platform
    $files = if ($Name) {
        @(Get-ChildItem -Path $toolsDir -Filter "$Name.json" -ErrorAction SilentlyContinue)
    } else {
        @(Get-ChildItem -Path $toolsDir -Filter '*.json' | Sort-Object Name)
    }

    foreach ($file in $files) {
        try {
            $tool = Get-Content $file.FullName -Raw | ConvertFrom-Json
        }
        catch {
            Write-Warning "Failed to parse $($file.Name): $_"
            continue
        }

        $spec = $tool.install.$platform.github
        if (-not $spec) { continue }

        [PSCustomObject]@{
            Name       = $tool.name
            Description = $tool.description
            Homepage   = $tool.homepage
            Verify     = $tool.verify
            SelfUpdate = $tool.selfUpdate
            Spec       = $spec
        }
    }
}

# --- Private: pick the right asset name for this architecture ---

function Resolve-CongruensAsset {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]$Spec
    )

    if ((Get-CongruensArch) -eq 'arm64' -and $Spec.assetArm64) {
        return $Spec.assetArm64
    }
    return $Spec.asset
}

# --- Private: local filename the asset should be saved as ---

function Resolve-CongruensBinaryName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]$Spec
    )

    # "as" lets a platform-suffixed asset (yt-dlp_linux) land under its real name.
    if ($Spec.as) {
        $name = $Spec.as
    } else {
        $name = Resolve-CongruensAsset -Spec $Spec
    }

    if ((Get-Platform) -eq 'windows' -and $name -notlike '*.exe') {
        $name = "$name.exe"
    }
    return $name
}

# --- Private: fetch and check the published SHA256 for an asset ---

function Test-CongruensChecksum {
    <#
    .SYNOPSIS
        Verify a downloaded file against the project's published checksum file.

    .OUTPUTS
        'ok', 'mismatch', or 'unavailable'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$ChecksumAsset,
        [Parameter(Mandatory)][string]$AssetName
    )

    $url = "https://github.com/$Repo/releases/latest/download/$ChecksumAsset"
    try {
        $response = Invoke-WebRequest -Uri $url -UseBasicParsing -ErrorAction Stop
        $content = [System.Text.Encoding]::UTF8.GetString($response.Content)
    }
    catch {
        return 'unavailable'
    }

    # Format is "<sha256>  <filename>", the same shape sha256sum produces.
    $expected = $null
    foreach ($line in ($content -split "`n")) {
        $parts = $line.Trim() -split '\s+', 2
        if ($parts.Count -eq 2 -and $parts[1].Trim() -eq $AssetName) {
            $expected = $parts[0].Trim()
            break
        }
    }

    if (-not $expected) { return 'unavailable' }

    $actual = (Get-FileHash -Path $Path -Algorithm SHA256).Hash
    if ($actual -ieq $expected) { return 'ok' }
    return 'mismatch'
}

# --- Private: download a release asset into the congruens bin dir ---

function Install-CongruensGitHubAsset {
    <#
    .SYNOPSIS
        Download a GitHub release asset and place it on PATH.

    .OUTPUTS
        'installed', 'current', or 'failed'
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][string]$ToolName,
        [Parameter(Mandatory)]$Spec,
        [switch]$OnlyIfChanged
    )

    $asset = Resolve-CongruensAsset -Spec $Spec
    if (-not $asset) {
        Write-Host "no asset defined for $(Get-CongruensArch)" -ForegroundColor Red
        return 'failed'
    }

    $binDir = Get-CongruensBinDir
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    }

    $binaryName = Resolve-CongruensBinaryName -Spec $Spec
    $destination = Join-Path $binDir $binaryName
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) "congruens-$ToolName-$([System.IO.Path]::GetRandomFileName())"

    # The /latest/download/ redirect needs no API call, so there is no rate limit.
    $url = "https://github.com/$($Spec.repo)/releases/latest/download/$asset"

    try {
        $previous = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        try {
            Invoke-WebRequest -Uri $url -OutFile $temp -UseBasicParsing -ErrorAction Stop
        }
        finally {
            $ProgressPreference = $previous
        }
    }
    catch {
        Write-Host "download failed: $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $temp) { Remove-Item $temp -Force -ErrorAction SilentlyContinue }
        return 'failed'
    }

    if ($Spec.checksums) {
        $result = Test-CongruensChecksum -Path $temp -Repo $Spec.repo -ChecksumAsset $Spec.checksums -AssetName $asset
        if ($result -eq 'mismatch') {
            Write-Host "checksum MISMATCH - discarded" -ForegroundColor Red
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
            return 'failed'
        }
        if ($result -eq 'unavailable') {
            Write-Host "checksum unavailable - " -ForegroundColor Yellow -NoNewline
        }
    }

    # Without a self-updater we detect "already current" by content, which avoids
    # needing a version-tracking state file entirely.
    if ($OnlyIfChanged -and (Test-Path $destination)) {
        $newHash = (Get-FileHash -Path $temp -Algorithm SHA256).Hash
        $oldHash = (Get-FileHash -Path $destination -Algorithm SHA256).Hash
        if ($newHash -eq $oldHash) {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
            return 'current'
        }
    }

    try {
        Move-Item -Path $temp -Destination $destination -Force -ErrorAction Stop
    }
    catch {
        Write-Host "could not write $destination : $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $temp) { Remove-Item $temp -Force -ErrorAction SilentlyContinue }
        return 'failed'
    }

    if ((Get-Platform) -ne 'windows') {
        chmod +x $destination 2>&1 | Out-Null
    }

    return 'installed'
}

# --- Public: install ---

function Install-CongruensTool {
    <#
    .SYNOPSIS
        Install self-managed tools from GitHub releases into ~/.congruens/bin.

    .DESCRIPTION
        Handles tools whose tools/*.json declares a "github" install block for
        the current platform. The binary is placed in ~/.congruens/bin, which
        profile.ps1 puts at the front of PATH so it wins over any package
        manager copy.

    .PARAMETER Name
        The tool to install (matches a JSON filename in tools/).

    .PARAMETER All
        Install every tool that declares a github block for this platform.

    .PARAMETER Force
        Re-download even if the binary is already present.

    .PARAMETER DryRun
        Show what would happen without downloading anything.

    .PARAMETER List
        List the tools that use the github install method.

    .EXAMPLE
        Install-CongruensTool yt-dlp

        Downloads the latest yt-dlp release binary onto PATH.

    .EXAMPLE
        Install-CongruensTool -All

        Installs every github-method tool that isn't already present.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [switch]$All,
        [switch]$Force,
        [switch]$DryRun,
        [switch]$List
    )

    if ($List -or (-not $Name -and -not $All)) {
        Show-CongruensToolList
        return
    }

    $tools = @(Get-CongruensGitHubTool -Name $Name)
    if ($tools.Count -eq 0) {
        if ($Name) {
            Write-Host ""
            Write-Host "  No github install method for '$Name' on $(Get-Platform)." -ForegroundColor Yellow
            Write-Host "  Run 'cgrupdate -List' to see which tools use it." -ForegroundColor DarkGray
            Write-Host ""
        } else {
            Write-Host "  No tools declare a github install block for $(Get-Platform)." -ForegroundColor Yellow
        }
        return
    }

    $binDir = Get-CongruensBinDir
    Write-Host ""
    Write-Host "  Installing into $binDir" -ForegroundColor Cyan
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray

    foreach ($tool in $tools) {
        $binaryName = Resolve-CongruensBinaryName -Spec $tool.Spec
        $destination = Join-Path $binDir $binaryName

        Write-Host ("  $($tool.Name)".PadRight(18)) -ForegroundColor Yellow -NoNewline

        if (-not $Force -and (Test-Path $destination)) {
            Write-Host "already installed" -ForegroundColor DarkGray -NoNewline
            Write-Host " (use -Force to re-download)" -ForegroundColor DarkGray
            continue
        }

        if ($DryRun) {
            $asset = Resolve-CongruensAsset -Spec $tool.Spec
            Write-Host "would download $asset from $($tool.Spec.repo)" -ForegroundColor DarkGray
            continue
        }

        $result = Install-CongruensGitHubAsset -ToolName $tool.Name -Spec $tool.Spec
        if ($result -eq 'installed') {
            Write-Host "OK" -ForegroundColor Green
        }
    }

    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host "  Restart your shell if $binDir was not already on PATH." -ForegroundColor DarkGray
    Write-Host ""
}

# --- Public: update ---

function Update-CongruensTool {
    <#
    .SYNOPSIS
        Update self-managed tools to their latest GitHub release.

    .DESCRIPTION
        For tools that declare a selfUpdate command (yt-dlp -U and friends),
        runs that command and lets the tool update itself in place. For the
        rest, re-downloads the latest release asset and replaces the binary
        only if the contents actually changed.

    .PARAMETER Name
        The tool to update. Omit to update every github-method tool.

    .PARAMETER DryRun
        Show what would be run or downloaded without changing anything.

    .PARAMETER List
        List the tools that use the github install method and their versions.

    .EXAMPLE
        cgrupdate

        Updates every self-managed tool.

    .EXAMPLE
        cgrupdate yt-dlp

        Updates just yt-dlp, via its own -U self-updater.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [switch]$DryRun,
        [switch]$List
    )

    if ($List) {
        Show-CongruensToolList
        return
    }

    $tools = @(Get-CongruensGitHubTool -Name $Name)
    if ($tools.Count -eq 0) {
        if ($Name) {
            Write-Host ""
            Write-Host "  No github install method for '$Name' on $(Get-Platform)." -ForegroundColor Yellow
            Write-Host "  Tools installed by winget/brew/apt update through those instead." -ForegroundColor DarkGray
            Write-Host ""
        } else {
            Write-Host "  No tools declare a github install block for $(Get-Platform)." -ForegroundColor Yellow
        }
        return
    }

    $binDir = Get-CongruensBinDir
    Write-Host ""
    Write-Host "  Updating self-managed tools" -ForegroundColor Cyan
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray

    foreach ($tool in $tools) {
        $binaryName = Resolve-CongruensBinaryName -Spec $tool.Spec
        $destination = Join-Path $binDir $binaryName

        Write-Host ("  $($tool.Name)".PadRight(18)) -ForegroundColor Yellow -NoNewline

        if (-not (Test-Path $destination)) {
            Write-Host "not installed" -ForegroundColor DarkGray -NoNewline
            Write-Host " (run 'cgrtool $($tool.Name)')" -ForegroundColor DarkGray
            continue
        }

        # Prefer the tool's own updater: it knows about deltas, nightly channels
        # and its own integrity checks in a way a blind re-download does not.
        if ($tool.SelfUpdate) {
            if ($DryRun) {
                Write-Host "would run: $($tool.SelfUpdate)" -ForegroundColor DarkGray
                continue
            }

            Write-Host "self-updating..." -ForegroundColor DarkGray
            $output = & $destination @($tool.SelfUpdate -split ' ' | Select-Object -Skip 1) 2>&1
            $output | ForEach-Object { Write-Host "                    $_" -ForegroundColor DarkGray }
            continue
        }

        if ($DryRun) {
            $asset = Resolve-CongruensAsset -Spec $tool.Spec
            Write-Host "would re-download $asset from $($tool.Spec.repo)" -ForegroundColor DarkGray
            continue
        }

        $result = Install-CongruensGitHubAsset -ToolName $tool.Name -Spec $tool.Spec -OnlyIfChanged
        switch ($result) {
            'installed' { Write-Host "updated" -ForegroundColor Green }
            'current'   { Write-Host "already current" -ForegroundColor DarkGray }
        }
    }

    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""
}

# --- Private: shared listing used by both -List switches ---

function Show-CongruensToolList {
    [CmdletBinding()]
    param()

    $tools = @(Get-CongruensGitHubTool)
    $binDir = Get-CongruensBinDir

    Write-Host ""
    Write-Host "  Self-managed tools (installed from GitHub releases):" -ForegroundColor Cyan
    Write-Host "  ────────────────────────────────────────────────────────" -ForegroundColor DarkGray
    Write-Host ""

    if ($tools.Count -eq 0) {
        Write-Host "  None defined for $(Get-Platform)." -ForegroundColor Yellow
        Write-Host ""
        Write-Host '  Add a "github" block to a tools/*.json install section to opt in.' -ForegroundColor DarkGray
        Write-Host ""
        return
    }

    foreach ($tool in $tools) {
        $binaryName = Resolve-CongruensBinaryName -Spec $tool.Spec
        $destination = Join-Path $binDir $binaryName

        $status = "not installed"
        $statusColor = "DarkGray"
        if (Test-Path $destination) {
            $status = "installed"
            $statusColor = "Green"
        }

        $padding = ' ' * [Math]::Max(1, 14 - $tool.Name.Length)
        Write-Host "  $($tool.Name)" -ForegroundColor Yellow -NoNewline
        Write-Host ("$padding$($tool.Spec.repo)".PadRight(34)) -ForegroundColor Gray -NoNewline
        Write-Host "[$status]" -ForegroundColor $statusColor -NoNewline
        if ($tool.SelfUpdate) {
            Write-Host "  self-updates" -ForegroundColor DarkGray
        } else {
            Write-Host ""
        }
    }

    Write-Host ""
    Write-Host "  Location: $binDir" -ForegroundColor DarkGray
    Write-Host ""
}

# --- Wrapper functions ---

function cgrupdate {
    <#
    .SYNOPSIS
        Update self-managed tools (yt-dlp and friends) to their latest release.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [switch]$DryRun,
        [switch]$List
    )

    Update-CongruensTool @PSBoundParameters
}

function cgrtool {
    <#
    .SYNOPSIS
        Install a self-managed tool from its GitHub release.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$Name,

        [switch]$All,
        [switch]$Force,
        [switch]$DryRun,
        [switch]$List
    )

    Install-CongruensTool @PSBoundParameters
}

# --- Tab completion for the Name parameter ---

$_cgrToolCompleter = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)

    Get-CongruensGitHubTool |
        Where-Object { $_.Name -like "$wordToComplete*" } |
        ForEach-Object {
            [System.Management.Automation.CompletionResult]::new(
                $_.Name,
                $_.Name,
                'ParameterValue',
                "$($_.Spec.repo) - $($_.Description)"
            )
        }
}

Register-ArgumentCompleter -CommandName 'Update-CongruensTool' -ParameterName 'Name' -ScriptBlock $_cgrToolCompleter
Register-ArgumentCompleter -CommandName 'Install-CongruensTool' -ParameterName 'Name' -ScriptBlock $_cgrToolCompleter
Register-ArgumentCompleter -CommandName 'cgrupdate' -ParameterName 'Name' -ScriptBlock $_cgrToolCompleter
Register-ArgumentCompleter -CommandName 'cgrtool' -ParameterName 'Name' -ScriptBlock $_cgrToolCompleter

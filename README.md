# congruens

A shared cross-platform CLI experience. Same muscle-memory, same look, everywhere.

## What It Does

Congruens provides a consistent terminal + agentic environment across Windows, macOS, and Linux:

- **PowerShell 7** as the unified shell
- **oh-my-posh** with a custom theme for a consistent prompt
- **Cross-platform commands** that work the same way everywhere
- **Declarative tool definitions** for reproducible machine setup
- **Agentic environment definition** for a reproducible llm setup

## Quick Start

### Windows

```powershell
# Run the bootstrap script (requires PowerShell 7)
.\bootstrap\windows.ps1

# Set up AI agent configurations
.\agents\install.ps1
```

### macOS / Linux

```bash
# Run the bootstrap script
./bootstrap/macos.sh   # or linux.sh

# Set up AI agent configurations
./agents/install.sh
```

The bootstrap scripts will:
1. Set up package managers
2. Install tools from `tools/*.json`
3. Link the PowerShell profile
4. Configure oh-my-posh with the custom theme

The agents install script will:
1. Set the `OPENCODE_CONFIG_DIR` env var for OpenCode
2. Create symlinks for Claude Code and Agent Skills standard
3. Link the shared skills and agent profile

## Repository Structure

```
congruens/
├── powershell/           # PowerShell module and profile
│   ├── profile.ps1       # Thin loader sourced by $PROFILE
│   └── Congruens/        # PowerShell module with cross-platform commands
│       ├── Private/      # Internal helpers (platform detection, PSReadLine)
│       └── Public/       # Exported commands (auto-sourced at import)
├── omp/                  # oh-my-posh configuration
│   └── congruens.omp.json
├── builtins/             # Metadata for the module's own commands (JSON, feeds cgrman)
├── tools/                # Declarative external tool definitions (JSON)
├── devenvs/              # Development environment definitions (JSON)
├── bootstrap/            # Platform-specific bootstrap scripts
├── agents/               # AI agent configurations (portable across tools)
│   ├── config/           # Config dir (OPENCODE_CONFIG_DIR points here)
│   │   └── skills/       # Shared agent skills
│   ├── install.sh/.ps1   # Agent setup scripts
│   └── settings_plan.md  # Permission guidelines for tool configs
└── config/               # Configuration files (defaults + gitignored local override)
```

## How It Works

### PowerShell Profile

Your `$PROFILE` sources a single line (path depends on where you cloned the repo):

```powershell
. "/path/to/congruens/powershell/profile.ps1"
```

This loads the Congruens module and initializes oh-my-posh. All customization lives in the repo, keeping the actual profile minimal and stable.

### Landing in PowerShell (macOS / Linux)

zsh (or bash) stays the login shell; congruens never injects `exec pwsh` into rc files. Hijacking
the login shell breaks terminal cwd tracking, app-launched terminals, and `$SHELL -c` callers.
Instead:

- **Ghostty** is configured by the bootstrap to open new terminals straight into PowerShell
  (`command = <pwsh>` in `~/.config/ghostty/config`). `ghostty -e <cmd>` still overrides it.
- **Other terminals**: set the profile shell to the pwsh path in their settings, or just type
  `pw` -- a small function the bootstrap adds to your rc file that swaps the current shell for
  PowerShell.

Re-running the bootstrap migrates away any `exec pwsh` block a previous congruens version
installed.

### Cross-Platform Commands

The Congruens module provides commands that abstract platform differences:

**Files and navigation**

| Command | Description |
|---------|-------------|
| `ll [path]` | Enhanced directory listing using eza (long format) |
| `mkcd <dir>` | Create directory (including parents) and cd into it |
| `open [path]` | Open in file explorer (Explorer/Finder/xdg-open) |
| `which <cmd>` | Find command location (works with aliases/functions) |
| `jump` | List all saved directory bookmarks |
| `jump <alias>` | cd to a bookmarked directory |
| `setjump <alias>` | Bookmark the current directory |
| `deljump <alias>` | Remove a bookmark |

**PATH and environment**

| Command | Description |
|---------|-------------|
| `cgrpath show` | Display PATH entries, one per line with index |
| `cgrpath addsession <dir>` | Add directory to current session PATH |
| `cgrpath addpermanent <dir>` | Add directory to PATH permanently |
| `cgrpath remove <dir>` | Remove directory from session PATH |
| `cgrenv show [name]` | Display all environment variables, or a specific one |
| `cgrenv addsession <name> <value>` | Set an environment variable for the current session |
| `cgrenv addpermanent <name> <value>` | Set an environment variable permanently |

**Discovery and setup**

| Command | Description |
|---------|-------------|
| `cgrman` | Show available subcommands |
| `cgrman builtins` | Browse built-in Congruens commands |
| `cgrman tools` | Browse external tool definitions |
| `cgrman devenvs` | Browse dev environment definitions |
| `cgrinstall -List` | Show available devenvs and install status |
| `cgrinstall <name>` | Install a dev environment (`-Force`, `-DryRun` supported) |
| `cgrtool <name>` | Install a self-managed tool from its GitHub release |
| `cgrtool -All` | Install every self-managed tool for this platform |
| `cgrupdate` | Update all self-managed tools |
| `cgrupdate <name>` | Update one self-managed tool |
| `cgrupdate -List` | Show self-managed tools and install status |
| `motd` | Show the welcome banner and fastfetch system info |

**Security**

| Command | Description |
|---------|-------------|
| `tirith-check check -- <cmd>` | Analyze a command without executing it |
| `tirith-check run <url>` | Safe replacement for `curl \| bash` |
| `tirith-check scan [path]` | Scan files/directories for hidden content |
| `tirith-check score <url>` | Trust-signal breakdown for a URL |

`tirith-check` wraps [tirith](https://github.com/sheeki03/tirith) and has more subcommands than
listed here -- run `cgrman builtins` for the full set.

Metadata for every built-in lives in `builtins/*.json`, which is what `cgrman` reads. Adding a
command means adding a JSON file, not editing a list in code.

### Adding a Built-In Command

1. Add a `.ps1` under `powershell/Congruens/Public/` with a formal PascalCase function and a
   short-name wrapper that splats `@PSBoundParameters` to it. Give it comment-based help, and a
   `Register-ArgumentCompleter` for both names if it takes arguments.
2. Export both names in `FunctionsToExport` in `powershell/Congruens/Congruens.psd1`, or the
   function exists in module scope and nobody can call it.
3. Drop a `builtins/<name>.json` with `name`, `description` and a `usage` list so `cgrman`
   picks it up.
4. Optionally add a tip line to `Show-Motd.ps1` so the command shows up in the startup rotation.
5. `Import-Module Congruens -Force`, run the command, and check it appears in `cgrman builtins`.

### Tool Definitions

Each file in `tools/` declares how to install a tool on each platform:

```json
{
  "name": "ripgrep",
  "description": "Fast regex-based search tool",
  "install": {
    "windows": { "winget": "BurntSushi.ripgrep.MSVC", "choco": "ripgrep" },
    "macos": { "brew": "ripgrep" },
    "linux": { "apt": "ripgrep", "dnf": "ripgrep", "pacman": "ripgrep" }
  },
  "verify": "rg --version"
}
```

Bootstrap scripts read these definitions and use the first available package manager. Which keys
are honoured depends on the platform: Windows tries `winget`, then `scoop`, then `choco`; macOS
uses `brew`; Linux uses whichever of `apt`/`dnf`/`pacman` it detected.

**Installs are one-shot.** Before installing, the bootstrap runs the first word of `verify` through
a command lookup, and skips the tool entirely if it resolves. Re-running bootstrap therefore
installs what is missing and never upgrades what is present -- updating installed tools is left to
each package manager (`winget upgrade`, `brew upgrade`, and so on). The exception is self-managed
tools, below.

### Self-Managed Tools

Some tools ship releases faster than any package manager follows. yt-dlp is the clearest case: it
publishes fixes almost daily, and `yt-dlp -U` **refuses to run** once it detects a package-manager
install, telling you to update through that manager instead. So the winget copy doesn't merely lag,
it disables the updater you actually want.

For those tools, congruens owns the binary. Declare a `github` block instead of package manager
keys:

```json
{
  "name": "yt-dlp",
  "install": {
    "windows": {
      "github": {
        "repo": "yt-dlp/yt-dlp",
        "asset": "yt-dlp.exe",
        "assetArm64": "yt-dlp_arm64.exe",
        "checksums": "SHA2-256SUMS"
      }
    },
    "linux": {
      "github": {
        "repo": "yt-dlp/yt-dlp",
        "asset": "yt-dlp_linux",
        "as": "yt-dlp",
        "checksums": "SHA2-256SUMS"
      }
    }
  },
  "selfUpdate": "yt-dlp -U",
  "verify": "yt-dlp --version"
}
```

| Key | Meaning |
|-----|---------|
| `repo` | GitHub `owner/name` |
| `asset` | Release asset filename (x64, or universal) |
| `assetArm64` | Optional asset used when running on arm64 |
| `as` | Optional local filename, for assets with a platform suffix |
| `checksums` | Optional checksum asset; verified before the binary is placed |
| `selfUpdate` | Optional command the tool provides to update itself |

Binaries land in `~/.congruens/bin`, which `profile.ps1` **prepends** to PATH so a congruens-owned
tool wins over a stale package-manager copy of the same name.

`cgrtool` installs, `cgrupdate` updates. Updating prefers the tool's own `selfUpdate` command; for
tools without one it re-downloads the asset and only replaces the binary if the contents actually
changed. Everything goes through the `/releases/latest/download/` redirect, so no GitHub API calls
are made and the unauthenticated 60-requests-per-hour limit never applies.

Scope is deliberately narrow: **single-file assets only**. Archive extraction and arch-triple
matching are not supported, because the tools that need same-day updates all ship plain binaries,
and the tools that ship archives don't need daily updates. Declaring a `github` block also *replaces*
the package manager keys for that platform rather than sitting alongside them -- otherwise you end up
with two copies and PATH order silently decides which one runs.

### Development Environments

Files in `devenvs/` define how to set up development environments with multi-step scripts:

```json
{
  "name": "node",
  "description": "Node.js runtime with nvm and npm",
  "install": {
    "windows": { "script": ["winget install CoreyButler.NVMforWindows", "nvm install lts"] },
    "macos": { "script": ["curl ... | bash", "nvm install --lts"] }
  },
  "verify": "node --version"
}
```

### oh-my-posh Theme

A two-line powerline prompt:

```
 ~/projects/congruens   main                                    3.2s  14:32
❯ _
```

- **Line 1 Left:** Path, git branch with status
- **Line 1 Right:** Execution time (>2s only), clock
- **Line 2:** Prompt symbol (turns red on error)

## Configuration

- **Clone location:** Anywhere you like -- all scripts resolve paths relative to the repo
- **Local overrides:** `config/congruens.local.json` (gitignored)
- **Git config:** Use git's include directive to source shared settings

## Design Principles

- **Functions over aliases** - More portable across platforms
- **Intent over flags** - Commands wrap common patterns (`mkcd` vs `mkdir && cd`)
- **Declarative over imperative** - Tools defined in JSON, scripts read definitions
- **Portable paths** - All scripts resolve paths relative to the repo root

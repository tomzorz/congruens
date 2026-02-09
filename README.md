# congruens

A shared cross-platform CLI experience. Same muscle-memory, same look, everywhere.

## What It Does

Congruens provides a consistent terminal environment across Windows, macOS, and Linux:

- **PowerShell 7** as the unified shell
- **oh-my-posh** with a custom theme for a consistent prompt
- **Cross-platform commands** that work the same way everywhere
- **Declarative tool definitions** for reproducible machine setup

## Quick Start

### Windows

```powershell
# Run the bootstrap script (requires PowerShell 7)
.\bootstrap\windows.ps1
```

### macOS / Linux

```bash
# Run the bootstrap script
./bootstrap/macos.sh   # or linux.sh
```

The bootstrap scripts will:
1. Set up package managers
2. Install tools from `tools/*.json`
3. Link the PowerShell profile
4. Configure oh-my-posh with the custom theme

## Repository Structure

```
congruens/
├── powershell/           # PowerShell module and profile
│   ├── profile.ps1       # Thin loader sourced by $PROFILE
│   └── Congruens/        # PowerShell module with cross-platform commands
├── omp/                  # oh-my-posh configuration
│   └── congruens.omp.json
├── tools/                # Declarative tool definitions (JSON)
├── devenvs/              # Development environment definitions (JSON)
├── bootstrap/            # Platform-specific bootstrap scripts
├── agents/               # AI agent configurations (portable across tools)
└── config/               # Configuration files
```

## How It Works

### PowerShell Profile

Your `$PROFILE` sources a single line:

```powershell
. "$HOME/dotfiles/powershell/profile.ps1"
```

This loads the Congruens module and initializes oh-my-posh. All customization lives in the repo, keeping the actual profile minimal and stable.

### Cross-Platform Commands

The Congruens module provides commands that abstract platform differences:

| Command | Description |
|---------|-------------|
| `ll [path]` | Enhanced directory listing using eza (long format) |
| `mkcd <dir>` | Create directory and cd into it |
| `open [path]` | Open in file explorer (Explorer/Finder/xdg-open) |
| `which <cmd>` | Find command location (works with aliases/functions) |
| `path show` | Display PATH entries, one per line |
| `path add <dir>` | Add to session PATH |

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

Bootstrap scripts read these definitions and use the first available package manager.

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

- **Dotfiles location:** `~/dotfiles` (fixed on all platforms)
- **Local overrides:** `config/congruens.local.json` (gitignored)
- **Git config:** Use git's include directive to source shared settings

## Design Principles

- **Functions over aliases** - More portable across platforms
- **Intent over flags** - Commands wrap common patterns (`mkcd` vs `mkdir && cd`)
- **Declarative over imperative** - Tools defined in JSON, scripts read definitions
- **Portable paths** - Always use `~` and `$HOME`, dotfiles at fixed location

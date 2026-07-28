# How to add a new built-in command to Congruens

**Date**: 2026-03-01
**Category**: decision
**Status**: open

## Context

Congruens has two categories of commands visible in `cgrman`: built-in commands
(our own PowerShell functions) and external tools (third-party CLIs). Both are
now discovered dynamically from JSON files. This note documents the full
checklist for adding either type so future sessions don't miss steps.

## Adding a new built-in command

### 1. Create the PowerShell function

Add a `.ps1` file in `powershell/Congruens/Public/`. Follow the established pattern:

- **Formal PascalCase function** (e.g., `Invoke-JumpCommand`) with full
  comment-based help (`.SYNOPSIS`, `.DESCRIPTION`, `.PARAMETER`, `.EXAMPLE`).
- **Short-name wrapper function** (e.g., `jump`) that redeclares parameter
  attributes (`ValidateSet`, `Mandatory`, etc.) and splats `@PSBoundParameters`
  to the formal function. This is required because PowerShell aliases don't
  carry parameter attributes.
- If the command takes user-facing arguments, add a `Register-ArgumentCompleter`
  in the same file for both the formal and short names.
- Private helpers (not exported) can live in the same file.

### 2. Register in the module manifest

Add both the formal name and the short name to `FunctionsToExport` in
`powershell/Congruens/Congruens.psd1`. If you skip this, the function will
exist in the module scope but won't be visible to the user.

### 3. Add metadata for cgrman

Drop a JSON file in `builtins/` (e.g., `builtins/jump.json`):

```json
{
  "name": "jump",
  "description": "Directory bookmarking: save, list, and jump to bookmarked paths",
  "usage": [
    { "command": "jump", "info": "List all saved bookmarks" },
    { "command": "jump <alias>", "info": "cd to the bookmarked directory" },
    { "command": "setjump <alias>", "info": "Bookmark the current directory under <alias>" },
    { "command": "deljump <alias>", "info": "Remove a bookmark" }
  ]
}
```

The filename doesn't matter (sorted alphabetically), but convention is to
match the primary command name. `cgrman` scans `builtins/*.json` dynamically,
so no code changes needed.

### 4. (Optional) Add tips to motd

Add one or more tip strings to the `$tips` array in
`powershell/Congruens/Public/Show-Motd.ps1` so the new command shows up in
the random tip rotation on shell startup.

### 5. Verify

- Open a new terminal (or `Import-Module Congruens -Force`).
- Run the command.
- Run `cgrman` and confirm the new command appears in the builtin list.
- Run `cgrman builtins` and browse to it.

## Adding a new external tool

### 1. Create the tool definition

Drop a JSON file in `tools/` (e.g., `tools/bat.json`):

```json
{
  "name": "bat",
  "description": "Cat clone with syntax highlighting and Git integration",
  "homepage": "https://github.com/sharkdp/bat",
  "install": {
    "windows": {
      "winget": "sharkdp.bat",
      "choco": "bat"
    },
    "macos": {
      "brew": "bat"
    },
    "linux": {
      "apt": "bat",
      "dnf": "bat",
      "pacman": "bat"
    }
  },
  "verify": "bat --version"
}
```

`cgrman tools` scans `tools/*.json` dynamically. The bootstrap scripts also
read these files to install tools, using the `verify` command to check if
already installed, then trying `winget` first, falling back to `choco` (on
Windows).

### 2. Verify

- Run `cgrman tools` and browse to it.
- Run the bootstrap script to confirm it installs (or skips if already present).

## Adding a self-managed tool (GitHub releases)

Use this instead of package manager keys when a tool releases faster than winget/brew/apt can
follow, or ships its own updater that refuses to run on package-manager installs (yt-dlp).

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

Rules:

- The `github` block **replaces** winget/brew/apt keys for that platform. Keeping both installs two
  copies and lets PATH order decide which runs, which is exactly the confusion this avoids.
- Single-file assets only. No archives, no tarballs. Check the real asset names first with
  `curl -sL https://api.github.com/repos/<owner>/<repo>/releases/latest | jq -r '.assets[].name'`.
- `as` renames a platform-suffixed asset (`yt-dlp_linux` -> `yt-dlp`). On Windows `.exe` is appended
  automatically if missing.
- `selfUpdate` is optional. Without it, `cgrupdate` re-downloads and compares hashes instead.
- No code changes needed anywhere. `Install-CongruensTool` discovers the block, and all three
  bootstrap scripts already detect it and delegate.

### Verify

- `cgrupdate -List` shows it.
- `cgrtool <name> -DryRun` then `cgrtool <name>`.
- `cgrupdate <name>` exercises the update path.

## File locations at a glance

| What | Where |
|------|-------|
| Built-in PS1 functions | `powershell/Congruens/Public/*.ps1` |
| Private helpers | `powershell/Congruens/Private/*.ps1` |
| Module manifest | `powershell/Congruens/Congruens.psd1` |
| Module loader | `powershell/Congruens/Congruens.psm1` |
| Built-in metadata (cgrman) | `builtins/*.json` |
| External tool definitions | `tools/*.json` |
| Self-managed tool install/update | `powershell/Congruens/Public/Install-CongruensTool.ps1` |
| Self-managed binary location | `~/.congruens/bin` (prepended to PATH by `profile.ps1`) |
| Bootstrap (Windows) | `bootstrap/windows.ps1` |
| MOTD / tips | `powershell/Congruens/Public/Show-Motd.ps1` |
| cgrman implementation | `powershell/Congruens/Public/Show-CongruensManual.ps1` |

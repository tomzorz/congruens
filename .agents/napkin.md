# Napkin

## Corrections
| Date | Source | What Went Wrong | What To Do Instead |
|------|--------|----------------|-------------------|
| 2026-03-01 | self | Used `2>nul` in bash on Windows, which created a literal file named `nul` (reserved device name, undeletable via normal tools) | Null device depends on shell context: git-bash uses `2>/dev/null` (MSYS2 emulates it), CMD/batch uses `>NUL`, PowerShell uses `>$null`. Never use `2>nul` in git-bash, it creates a literal file. To delete a `nul` file if it happens again: Python `ctypes.windll.kernel32.DeleteFileW("\\\\?\\path\\nul")` |

## User Preferences
- Use `Register-ArgumentCompleter` for dynamic tab completion, not just `ValidateSet`
- Module follows a pattern: formal PascalCase function + short-name wrapper function that splats `@PSBoundParameters`
- Wrapper functions must redeclare parameter attributes (ValidateSet, etc.) because aliases don't carry them
- Private helpers in the same .ps1 file are fine (they don't get exported if not in the manifest)

## Patterns That Work
- `Register-ArgumentCompleter` with `CompletionResult::new(text, listText, type, tooltip)` for rich tab completion
- Storing completers in the same .ps1 file as the functions they complete (keeps things cohesive)
- Using `ConvertFrom-Json -AsHashtable` for JSON config files (returns mutable hashtable, not PSCustomObject)
- `TabExpansion2` for testing completers programmatically without needing an interactive terminal
- pwsh `-File -` with heredoc `<<'PWSH'` to avoid bash interpolation issues with `$_`
- JSON metadata files for dynamic discovery (builtins/*.json, tools/*.json) instead of hardcoded lists in code
- PSReadLine config as Private/ function called from .psm1 at import time (session-level setup inside module scope)

## Patterns That Don't Work
- Passing PowerShell scripts with `$_` via bash `-Command` flag (bash eats the `$_` before pwsh sees it)
- `2>nul` in git-bash on Windows creates a literal file named `nul`. Use `2>/dev/null` instead.

## Domain Notes
- Congruens is a cross-platform CLI experience module (PowerShell 7+)
- Module path: `powershell/Congruens/`, loaded via `profile.ps1` which adds to `$env:PSModulePath`
- Auto-sources all `*.ps1` from `Private/` then `Public/` directories
- Tools catalog lives in `tools/*.json` (38 external tool definitions)
- Built-in command metadata lives in `builtins/*.json` (9 command definitions)
- `cgrman` has subcommands: `builtins` and `tools` (bare `cgrman` shows summary index)
- Platform detection via private helpers: `Test-IsWindows`, `Test-IsMac`, `Test-IsLinux`, `Get-Platform`
- Module loads from repo in-place (no copy step), so new commands are available after `Import-Module -Force`

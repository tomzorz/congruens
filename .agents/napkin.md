# Napkin

## Corrections
| Date | Source | What Went Wrong | What To Do Instead |
|------|--------|----------------|-------------------|

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

## Patterns That Don't Work
- Passing PowerShell scripts with `$_` via bash `-Command` flag (bash eats the `$_` before pwsh sees it)

## Domain Notes
- Congruens is a cross-platform CLI experience module (PowerShell 7+)
- Module path: `powershell/Congruens/`, loaded via `profile.ps1` which adds to `$env:PSModulePath`
- Auto-sources all `*.ps1` from `Private/` then `Public/` directories
- Tools catalog lives in `tools/*.json` (38 external tool definitions)
- Platform detection via private helpers: `Test-IsWindows`, `Test-IsMac`, `Test-IsLinux`, `Get-Platform`

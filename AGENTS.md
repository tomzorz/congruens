# Congruens: agent notes for this repository

The shared coding profile lives at `agents/config/AGENTS.md` and is installed as every machine's global profile by `agents/install.ps1` / `agents/install.sh`. This file only holds what is specific to working in the congruens repository itself.

## Working here

- Anything worth keeping past this session goes through the Record skill. It reads `AGENTS.records.md` next to this file for where each kind of information lives here. "Remember this" and "park this" are always worth keeping; anything the code or git history already says never is.

## PowerShell module conventions

- Every public command is a formal PascalCase function (`Invoke-JumpCommand`) plus a short-name wrapper (`jump`) that splats `@PSBoundParameters` to it. Both names are exported from `Congruens.psd1`.
- The wrapper redeclares every parameter attribute (`ValidateSet`, `Mandatory`, and so on). Aliases carry none of them, which is why the wrapper is a function and not an alias.
- Commands with user-facing arguments get a `Register-ArgumentCompleter` for both names, returning `CompletionResult` objects, in the same file as the function. `ValidateSet` alone is not tab completion.
- Private helpers may live in the same file as the command that uses them. Only names in the manifest are exported.
- Test completers programmatically with `TabExpansion2`; no interactive terminal needed.

## PowerShell gotchas

- Run pwsh from bash with `pwsh -File -` and a quoted heredoc. Passing the script through `-Command` lets bash eat `$_` before pwsh sees it.
- A method call on a literal passed as a command argument is literal text, not a call: `Write-Host "x".PadRight(18)` prints the method name. Wrap it: `Write-Host ("x".PadRight(18))`.
- The escape character in double-quoted strings is a backtick, not `\`. For embedded double quotes use a single-quoted string.
- `if` always needs braces. `if ($x) { return }`, never `if ($x) return`.

## Bootstrap scripts

- When changing the shape of a block the bootstrap injects into an rc file, detect the old shape with a unique grep and strip it with awk before appending the new one. A bare "marker present, skip" leaves every existing machine on the old behaviour after a pull.

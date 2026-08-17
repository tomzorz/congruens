# Napkin

## Corrections
| Date | Source | What Went Wrong | What To Do Instead |
|------|--------|----------------|-------------------|
| 2026-03-01 | self | Used `2>nul` in bash on Windows, which created a literal file named `nul` (reserved device name, undeletable via normal tools) | Null device depends on shell context: git-bash uses `2>/dev/null` (MSYS2 emulates it), CMD/batch uses `>NUL`, PowerShell uses `>$null`. Never use `2>nul` in git-bash, it creates a literal file. To delete a `nul` file if it happens again: Python `ctypes.windll.kernel32.DeleteFileW("\\\\?\\path\\nul")` |
| 2026-07-29 | user | Chained many commands into one bash call (`cd X && git status && git branch && git log ...`). Compound commands don't match per-command permission allowlist patterns, so they trigger security prompts that individual commands would sail through | One small command per tool call; run independent ones as parallel calls. Chain only when steps need one shell invocation (cd dependency, env var, pipe). Now a rule in AGENTS.md Tooling & Workflow |
| 2026-07-29 | user | Volunteered time-effort estimates ("takes a week by hand" style). They assume hand-written dev pace and are almost always nonsense in agentic workflows | Never estimate time effort unless explicitly asked. Describe scope concretely instead (files, steps, risk). Now a rule in AGENTS.md Communication Preferences |

## User Preferences
- Use `Register-ArgumentCompleter` for dynamic tab completion, not just `ValidateSet`
- Module follows a pattern: formal PascalCase function + short-name wrapper function that splats `@PSBoundParameters`
- Wrapper functions must redeclare parameter attributes (ValidateSet, etc.) because aliases don't carry them
- Private helpers in the same .ps1 file are fine (they don't get exported if not in the manifest)

## Patterns That Don't Work (Install Scripts)
- Bootstrap scripts append `exec pwsh` to .zshrc/.bashrc. Any env var exports added after that block never run because exec replaces the shell. The agents/install.sh set_env_var function must insert before the auto-launch block, not blindly append.
- `exec pwsh` in rc files hijacks IDE integrated terminals (VSCode, JetBrains). Guard with TERM_PROGRAM and TERMINAL_EMULATOR checks.
- `https://aka.ms/powershell-release?tag=stable` redirect is unreliable on macOS. Use `https://github.com/PowerShell/PowerShell/releases/latest` instead (GitHub's own redirect, always works).
- peon-ping's `install.ps1` is NOT standalone despite what its README implies: it dot-sources `scripts/install-utils.ps1` relative to itself and dies when downloaded as a single file (verified 2026-08-05). Fetch the repo zip and run install.ps1 from the extracted tree. The bash `install.sh` is different: it self-fetches its components, so `curl | bash` works there.
- peon-ping's installer over-subscribes Claude Code hooks (~10 events incl `PreToolUse`, which fires on EVERY tool call) and rewrites `~/.claude/settings.json` with a UTF-8 BOM via PS 5.1 `Set-Content` (verified 2026-08-09). On Windows the BOM makes Claude Desktop's strict JSON parser reject its own config, and the `PreToolUse` firehose spawns a PowerShell per tool call that leaks/hangs (peon.ps1 reads stdin with a blocking `ReadToEnd()` whose safety timer can't fire) and destabilises the app; crashes during the app's self-update then corrupt the MSIX -> the "There's a problem with Claude, reinstall" loop. `bootstrap/windows.ps1` now normalises after peon install: drops `SubagentStart/PreToolUse/PostToolUseFailure/UserPromptSubmit`, rewrites settings.json as UTF-8 no-BOM (round-trips fine because the bootstrap is `#Requires -Version 7.0`; a 5.1 ConvertTo-Json would corrupt the single-element hook arrays), and sets `desktop_notifications=false` on the WINDOWS config.json only. The nice peon notification banner (orc icon, colour-by-source) is a macOS-only Cocoa overlay (`scripts/mac-overlay*.js`); Windows only has a PowerShell-branded toast, so the shared `agents/config/peon-ping.json` seed keeps `desktop_notifications=true` for the Mac/Linux overlay. Re-running peon's own installer to update re-adds the full hook set + BOM; since 2026-08-17 the normalisation runs on every `bootstrap/windows.ps1` run instead of only after a fresh install, so a plain bootstrap re-run repairs it.

## Patterns That Work
- IDE terminal detection: `TERM_PROGRAM=vscode` for VSCode, `TERMINAL_EMULATOR=JetBrains-JediTerm` for JetBrains. Both set before rc files are sourced. Use as guards in auto-launch blocks.
- `Register-ArgumentCompleter` with `CompletionResult::new(text, listText, type, tooltip)` for rich tab completion
- Storing completers in the same .ps1 file as the functions they complete (keeps things cohesive)
- Using `ConvertFrom-Json -AsHashtable` for JSON config files (returns mutable hashtable, not PSCustomObject)
- `TabExpansion2` for testing completers programmatically without needing an interactive terminal
- pwsh `-File -` with heredoc `<<'PWSH'` to avoid bash interpolation issues with `$_`
- JSON metadata files for dynamic discovery (builtins/*.json, tools/*.json, devenvs/*.json) instead of hardcoded lists in code
- PSReadLine config as Private/ function called from .psm1 at import time (session-level setup inside module scope)
- ~~When zsh auto-launches PowerShell via `exec pwsh`, shell-specific PATH entries like `~/.bun/bin` may not survive unless `powershell/profile.ps1` reconstructs them.~~ **CORRECTED 2026-04-20**: `exec pwsh` does inherit exported env. The real issue is ordering: third-party installers (Bun, etc.) append exports to `~/.zshrc` *after* the auto-launch block, so they never run. Fix is generic, not Bun-specific: defer `exec pwsh` via `precmd` (zsh) / `PROMPT_COMMAND` (bash) so the whole rc file is sourced first.

## Patterns That Don't Work
- `Start-Process -ArgumentList @('--logo', 'Windows 11_small')` splits the space: ArgumentList is joined with spaces and NOT re-quoted, so the target sees `--logo Windows 11_small` as three args. Embed quotes in the element itself (`'"Windows 11_small"'`) on Windows.
- `Write-Host "text".PadRight(18)` does NOT call the method. In argument (command) parsing mode PowerShell treats the method call as literal text. Wrap it: `Write-Host ("text".PadRight(18))`. Same trap for any method call on a literal passed as an argument.
- C-style `\"` escaping inside PowerShell double-quoted strings. The escape char is a backtick; for embedded double quotes use a single-quoted string instead.
- PowerShell `if` always requires braces: `if ($x) { return }` not `if ($x) return`. The parser rejects braceless bodies, unlike C#/bash.
- PSReadLine on macOS/Linux crashes with IOException if `/tmp/.dotnet/shm` doesn't exist. .NET named mutexes require it. Pre-create the dir before PSReadLine init.
- Passing PowerShell scripts with `$_` via bash `-Command` flag (bash eats the `$_` before pwsh sees it)
- `2>nul` in git-bash on Windows creates a literal file named `nul`. Use `2>/dev/null` instead.
- `sed -i` is not portable across macOS/Linux. BSD sed (macOS) requires `sed -i '' "expr"`, GNU sed (Linux) requires `sed -i "expr"`. Use a `_sed_i` wrapper that checks `uname` to pick the right form.

## Domain Notes (Tool Updates)
- **Bootstrap is install-only by design.** All three scripts run the first word of `verify` through a command lookup and `continue` if it resolves. Re-running bootstrap never upgrades anything. This is intentional, not a bug -- don't "fix" it by removing the skip.
- **Install-only applies to installers, not to config.** The peon-ping section used to gate BOTH on one `-d ~/.claude/hooks/peon-ping` check, so a machine that had peon-ping but never got the shared `config.json` (installed before the seed existed, or config deleted) stayed broken through every later bootstrap. Fixed 2026-08-17: the hooks-dir check now only skips the installer; seeding the config and installing the pack roster run on every bootstrap, guarded by their own existence checks (config seeded only if missing, packs compared per-directory against `packs/<name>`). Same shape applies to any future section -- skip the download, still converge the config.
- ~~`config/congruens.defaults.json` has dead keys~~ **CLEANED 2026-07-29**: `tools.autoUpdate`, `installMissing`, and `preferredPackageManager` removed (nothing ever read them). Note the bootstraps still only COPY defaults to local; nothing reads the content of either file yet (`theme.ohMyPosh` and `projectRoots` are aspirational too, kept for now).
- `yt-dlp -U` refuses to run when it detects a package-manager install (winget/brew/pip) and tells you to use that manager instead. So the winget copy doesn't just lag behind daily releases, it disables the self-updater. This is why the `github` install method exists.
- **`github` install method** (added 2026-07-27): tools/*.json can declare `install.<platform>.github` = `{repo, asset, assetArm64?, as?, checksums?}` plus a top-level `selfUpdate`. Binary goes to `~/.congruens/bin`, which `profile.ps1` PREPENDS to PATH so it beats a package-manager copy. Implemented once in `powershell/Congruens/Public/Install-CongruensTool.ps1`; the three bootstrap scripts detect the key, skip the tool in their own loop, and shell out to `pwsh -NoProfile` to call `Install-CongruensTool -All`. Do not reimplement download logic in bash.
- Scope is single-file assets only. No archive extraction, no arch-triple matching beyond an optional `assetArm64`. Deliberate: daily-release tools ship plain binaries.
- ~~Known gap: `tools/tirith.json` declares `"cargo"` but no bootstrap reads a `cargo` key.~~ **FIXED 2026-07-27**: all three bootstraps now try `cargo install` as a last-resort fallback when the native package managers have no package and cargo is on PATH.

## Patterns That Work (GitHub Release Downloads)
- Use `https://github.com/<owner>/<repo>/releases/latest/download/<asset>` -- a plain redirect, no API call, so the unauthenticated 60-req/hr GitHub API limit never applies. Only hit `api.github.com` if you genuinely need release metadata.
- To detect "already up to date" without a version state file: download to temp, compare `Get-FileHash` of temp vs the installed binary, discard if identical. Removes an entire class of state-tracking bugs.
- Checksum files (`SHA2-256SUMS` etc.) are `<hash>  <filename>` -- split on `\s+` with a max of 2 parts, match on filename.
- Set `$ProgressPreference = 'SilentlyContinue'` around `Invoke-WebRequest -OutFile` or the progress bar makes large downloads dramatically slower in PS7.

## Domain Notes (Agents Config)
- **AGENTS.md was never actually being linked** (found and fixed 2026-07-27). Both `agents/install.ps1` and `agents/install.sh` looked for `$DotfilesDir/AGENTS.md` (repo root), but the file lives at `agents/config/AGENTS.md`. Both call sites guard with a file-exists check, so the symlink silently no-op'd and `~/.claude/CLAUDE.md` never existed. Lesson: a `if (Test-Path X) { link }` guard turns a wrong path into silence, not an error. When adding a guarded symlink, log the skip.
- Specifications in this repo are written in **Lojbanlite** (the `lojbanlite` skill plus the "Specification Writing" section of AGENTS.md).
- Lojbanlite and the Humanizer skill are mutually exclusive: Lojbanlite for specs, Humanizer for narrative prose. Never both on one text.

## Domain Notes
- `tirith-check` is the only export with an unapproved PowerShell verb. Suppressed via `Import-Module -DisableNameChecking` in profile.ps1 (deliberate: muscle-memory name beats verb compliance). Don't rename it, and don't remove the flag.
- Show-Motd runs fastfetch with `config/fastfetch.jsonc` (small logo, 11 essential modules) when the file exists, falls back to plain fastfetch otherwise. Plain `fastfetch` on the CLI still gives full output.
- fastfetch `"type": "small"` only has a Windows 11 small logo; on Windows 10 and older it falls back to the unknown-OS question mark. Show-Motd passes `--logo "Windows 11_small"` explicitly on Windows builds < 22000 (fixed 2026-08-05).
- Agent skills live in `agents/config/skills/<name>/SKILL.md` (frontmatter: name, description, author: congruens, version, date). NOT in `.github/skills` or user dir directly.
- `agents/install.ps1` symlinks `agents/config/skills` → `~/.agents/skills` and `~/.claude/skills`.
- Congruens is a cross-platform CLI experience module (PowerShell 7+)
- Module path: `powershell/Congruens/`, loaded via `profile.ps1` which adds to `$env:PSModulePath`
- Auto-sources all `*.ps1` from `Private/` then `Public/` directories
- Tools catalog lives in `tools/*.json` (38 external tool definitions)
- Built-in command metadata lives in `builtins/*.json` (10 command definitions, including cgrinstall)
- `cgrman` has subcommands: `builtins`, `tools`, and `devenvs` (bare `cgrman` shows summary index)
- `cgrinstall` installs devenvs by name from `devenvs/*.json` definitions (supports -List, -Force, -DryRun)
- Devenv JSON schema: `install.<platform>.script` (array of commands), `env.<platform>` (map of env vars), `verify`, `homepage`
- Platform detection via private helpers: `Test-IsWindows`, `Test-IsMac`, `Test-IsLinux`, `Get-Platform`
- Module loads from repo in-place (no copy step), so new commands are available after `Import-Module -Force`

## Patterns That Don't Work (Shell Startup & PATH)
- `exec pwsh` in `~/.zshrc` without guards hijacks IDE terminals (VSCode, JetBrains). Guard with `[[ -z "$TERM_PROGRAM" && -z "$TERMINAL_EMULATOR" ]]`.
- Env var exports after `exec pwsh` in `~/.zshrc` never run because exec replaces the shell process. Move all exports before exec or set them in PowerShell's profile.
- PowerShell doesn't inherit zsh's PATH when launched via `exec pwsh`. PowerShell starts with a fresh environment. Must set up Homebrew/Bun paths in PowerShell's profile (`~/.config/powershell/profile.ps1`).
- Bun's `source ~/.bun/_bun` in `~/.zshrc` can hang if `~/.bun` has insecure permissions (world/group writable). Fix: `chmod 755 ~/.bun && chmod 755 ~/.bun/bin`.

## Patterns That Work (Shell Startup & PATH)
- **rc-file `exec pwsh` is DEAD (2026-07-29). Do not resurrect it in any shape.** Two generations of patches (IDE guards, precmd deferral) still broke terminal cwd tracking (shell-integration/OSC 7 hooks are zsh-side and die on exec), app-launched terminals with params, and `$SHELL -c` callers, and the guard list was whack-a-mole (ghostty was never in it). The launch now lives in the TERMINAL EMULATOR config: Ghostty `command = <pwsh>` (bootstrap writes it; `ghostty -e` still overrides it, so app-launched commands work). rc files get only a `pw() { exec pwsh "$@"; }` opt-in function. zsh/bash stays the login shell for the whole OS.
- The `_strip_autolaunch` awk in the bootstraps handles all three historical block shapes (bare-exec ends `^fi$`, zsh hook ends with add-zsh-hook line, bash hook ends with PROMPT_COMMAND line). If a fourth shape ever existed, add its end pattern there.
- Set up Homebrew in PowerShell profile: `$brewPrefix = if (Test-Path /opt/homebrew) { '/opt/homebrew' } else { '/usr/local' }; $env:PATH = "$brewPrefix/bin:$brewPrefix/sbin:$env:PATH"`
- Set up Bun in PowerShell profile: `$env:BUN_INSTALL = "$env:HOME/.bun"; $env:PATH = "$env:BUN_INSTALL/bin:$env:PATH"`
- zsh startup order for login shells: `/etc/zshenv` → `~/.zshenv` → `/etc/zprofile` → `~/.zprofile` → `/etc/zshrc` → `~/.zshrc` → `/etc/zlogin` → `~/.zlogin`.
- macOS login bash shells (Terminal.app default) read `~/.bash_profile` but NOT `~/.bashrc`. Source `.bashrc` from `.bash_profile` to unify (bootstrap still does this).
- Bootstrap migrations: when changing the shape of an injected rc-file block, detect the OLD shape with a unique grep and strip it via `awk` before appending the new shape. Do NOT just `grep -q marker; skip` because that leaves users stuck on the old behavior after pulling.

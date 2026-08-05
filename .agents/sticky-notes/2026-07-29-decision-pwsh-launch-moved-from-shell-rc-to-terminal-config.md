# Decision: pwsh auto-launch moved from shell rc files to terminal emulator config

**Date**: 2026-07-29
**Category**: decision
**Status**: decided

## Context

Congruens auto-launched PowerShell by injecting `exec pwsh` into `~/.zshrc` / `~/.bash_profile`
(macOS) and `~/.bashrc` / `~/.zshrc` (Linux). The design was patched twice (IDE terminal guards,
then precmd/PROMPT_COMMAND deferral so installer exports load first) and still broke a third and
fourth way on the user's Mac:

- **Terminal cwd tracking died.** Ghostty/iTerm/Terminal.app inject shell-integration hooks
  (OSC 7 cwd reporting, prompt marks) into *zsh*. `exec pwsh` replaces zsh after the hooks load,
  so new tabs/splits stopped opening in the current directory ("paths don't register").
- **App-launched terminals broke.** Apps that open a terminal with a command or params expect a
  POSIX shell to receive them; they got PowerShell instead. The guard list (VSCode, JetBrains)
  could never cover every terminal; Ghostty was not in it.

Root cause: hijacking the login shell breaks every program that talks to "the shell". Not
patchable by adding guards.

## Decision

Keep the launch-into-PowerShell experience, move the mechanism:

1. **Terminal emulator config owns the launch.** Bootstrap writes
   `command = <pwsh path>` into `~/.config/ghostty/config` (marker:
   `# Congruens: launch PowerShell`). `ghostty -e <cmd>` overrides `command`, so app-launched
   terminals with explicit commands keep working. Other terminals (Terminal.app, iTerm) can be
   pointed at pwsh in their own profile settings manually.
2. **rc files get only an opt-in.** `pw() { exec pwsh "$@"; }` (marker:
   `# Congruens: pwsh opt-in`). Typing `pw` hops into PowerShell from any shell.
3. **zsh/bash remains the login shell system-wide.** No chsh to pwsh (breaks `$SHELL -c`
   callers expecting POSIX syntax).
4. **Migration is automatic.** `_strip_autolaunch` in both bootstraps removes all three
   historical block shapes (bare exec ending `fi`, zsh precmd hook, bash PROMPT_COMMAND hook) on
   the next bootstrap run, then appends the pw block. Verified against fixtures for all three
   shapes; idempotent.

## Follow-ups

- On the Mac: pull, re-run `bootstrap/macos.sh`, restart Ghostty. If Terminal.app or iTerm
  should also open into pwsh, set their profile shell to the pwsh path manually.
- Ghostty pwsh shell integration is limited compared to zsh (cwd tracking inside pwsh sessions
  may still be imperfect); that is a Ghostty/pwsh limitation, not a congruens regression.
- If a machine's rc files were hand-edited into a fourth block shape, add its end pattern to the
  `_strip_autolaunch` awk.

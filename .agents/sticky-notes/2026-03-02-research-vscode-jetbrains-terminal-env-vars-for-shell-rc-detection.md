# Research: VSCode and JetBrains terminal env vars for shell rc detection

**Date**: 2026-03-02
**Category**: research
**Status**: done

## Context

Needed a definitive list of environment variables set by VSCode and JetBrains IDEs when they spawn integrated terminal sessions, specifically ones available BEFORE shell rc files are sourced.

## Content

### Recommended Guards

```bash
# VSCode
[[ "$TERM_PROGRAM" == "vscode" ]]

# JetBrains (all IDEs)
[[ "$TERMINAL_EMULATOR" == "JetBrains-JediTerm" ]]
```

### VSCode (10 vars total, 3 high confidence)

- `TERM_PROGRAM=vscode` (Electron app level, always set, official recommendation)
- `VSCODE_INJECTION=1` (env mixin, before rc files)
- `VSCODE_SHELL_INTEGRATION=1` (set in integration scripts, before user rc content)
- `VSCODE_STABLE` (1 or 0), `VSCODE_NONCE`, `VSCODE_SHELL_LOGIN`, `ZDOTDIR`/`USER_ZDOTDIR`, `VSCODE_PATH_PREFIX`, `VSCODE_SHELL_ENV_REPORTING`, `VSCODE_A11Y_MODE`

### JetBrains (7 vars total, 2 high confidence)

- `TERMINAL_EMULATOR=JetBrains-JediTerm` (always set, all IDEs)
- `TERM_SESSION_ID` (random UUID per tab)
- `LOGIN_SHELL`, `JEDITERM_USER_RCFILE`, `JEDITERM_SOURCE`, `__INTELLIJ_COMMAND_HISTFILE__`, `_INTELLIJ_FORCE_SET_*`/`_INTELLIJ_FORCE_PREPEND_*`

### Key Source Files

- VSCode: `terminalEnvironment.ts` (getShellIntegrationInjection), `shellIntegration-bash.sh`
- JetBrains: `TerminalEnvironment.kt`, `LocalOptionsConfigurer.java`, `bash-integration.bash`

## Action / Next Steps

Reference is complete. HTML diagram saved at `~/.agent/diagrams/ide-terminal-env-vars-reference.html`.

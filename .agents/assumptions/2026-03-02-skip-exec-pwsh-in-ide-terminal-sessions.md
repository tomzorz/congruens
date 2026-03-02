# Assumptions: Skip exec pwsh in IDE terminal sessions (VSCode, JetBrains)

**Date**: 2026-03-02
**Task**: Prevent bootstrap auto-launch block from exec-ing pwsh when the shell is opened by an IDE

| # | Assumption | Confidence | Validated? | Outcome |
|---|-----------|------------|------------|---------|
| 1 | VSCode sets TERM_PROGRAM=vscode when spawning integrated terminals | high | confirmed | Well-documented, widely relied on by shell integrations |
| 2 | JetBrains IDEs set TERMINAL_EMULATOR=JetBrains-JediTerm when spawning terminals | medium | pending | Referenced in the YouTrack article, need to verify env var name |
| 3 | JetBrains also sets JETBRAINS_IDE or similar IDE-specific env vars | low | pending | Some reports mention INTELLIJ_ENVIRONMENT_READER but that's for env loading, not terminal |
| 4 | Checking TERM_PROGRAM and TERMINAL_EMULATOR is sufficient to cover both IDEs | medium | pending | May need VSCODE_PID as fallback for older VSCode versions |
| 5 | These env vars are set before the rc file is sourced (not after) | high | pending | Must be true for the guard to work; IDEs set env before launching the shell |

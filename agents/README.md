# Agent Configuration

Shared skills, subagents, and settings for AI coding assistants (OpenCode, Claude Code, and other [Agent Skills](https://agentskills.io)-compatible tools).

## Installation

**Windows (PowerShell):**
```powershell
.\agents\install.ps1
```

**macOS/Linux:**
```bash
./agents/install.sh
```

The install scripts:
- Set `OPENCODE_CONFIG_DIR` to point to `agents/config/`
- Symlink skills and agents into `~/.claude/` for Claude Code
- Symlink skills into `~/.agents/` for the Agent Skills standard

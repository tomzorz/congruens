# Agent Configuration

Portable agent skills, subagents, and settings for AI coding assistants.

> **See also**: The root [`AGENTS.md`](../AGENTS.md) file provides project context to all AI tools.
> It works with OpenCode, Claude Code (`CLAUDE.md` compatible), and other agentic tools.

This directory contains shared configurations that work across multiple agentic development tools:

| Tool | Skills Path | Agents Path | Settings |
|------|-------------|-------------|----------|
| **OpenCode** | `.opencode/skills/` | `.opencode/agents/` | `opencode.json` |
| **Claude Code** | `.claude/skills/` | `.claude/agents/` | `settings.json` |
| **Agent Skills Standard** | `.agents/skills/` | `.agents/` | - |

All tools follow the [Agent Skills](https://agentskills.io) open standard for cross-tool compatibility.

---

## Directory Structure

```
agents/
├── README.md                    # This file
├── skills/                      # Reusable instruction sets (SKILL.md files)
│   ├── code-reviewer/
│   │   └── SKILL.md
│   ├── debugger/
│   │   └── SKILL.md
│   └── explain-code/
│       └── SKILL.md
├── subagents/                   # Specialized agent definitions
│   ├── researcher.md
│   └── documentation.md
├── settings/                    # Shared settings and permissions
│   ├── opencode.json            # OpenCode settings template
│   ├── claude-settings.json     # Claude Code settings template
│   └── permissions.json         # Shared permission rules
└── scripts/                     # Installation and utility scripts
    ├── install.ps1              # Windows installer
    ├── install.sh               # Unix installer
    └── validate-query.sh        # Example hook script
```

---

## Concepts

### Skills

Skills are reusable instruction sets that extend what the AI can do. Each skill is a `SKILL.md` file with YAML frontmatter and markdown content.

**When to use skills:**
- Reference content (conventions, patterns, style guides)
- Task workflows (deployment, commit, code generation)
- Domain knowledge the AI should apply contextually

**Example skill:**
```yaml
---
name: code-reviewer
description: Reviews code for quality, security, and best practices
allowed-tools: Read, Grep, Glob
---

When reviewing code, focus on:
1. Code quality and readability
2. Security vulnerabilities
3. Performance implications
4. Test coverage
```

### Subagents

Subagents are specialized AI assistants that run in isolated contexts with custom prompts and tool access. Primary agents can spawn subagents for specific tasks.

**When to use subagents:**
- Isolate high-volume operations (test runs, log processing)
- Enforce strict tool restrictions
- Run parallel research tasks
- Specialize behavior for specific domains

**Example subagent:**
```yaml
---
name: researcher
description: Fast read-only agent for codebase exploration
tools: Read, Grep, Glob
model: haiku
---

You are a research assistant. Explore the codebase to answer questions.
Do not modify any files.
```

### Modes (Primary Agents)

Primary agents are top-level agents you interact with directly. Switch between them with Tab key.

| Mode | Purpose | Tool Access |
|------|---------|-------------|
| **Build** | Default development work | All tools enabled |
| **Plan** | Analysis without changes | Read-only, writes require approval |

---

## Installation

### Quick Install (Symlinks)

Run the install script to create symlinks from standard tool locations to this shared config:

**Windows (PowerShell):**
```powershell
. ~/dotfiles/agents/scripts/install.ps1
```

**macOS/Linux:**
```bash
~/dotfiles/agents/scripts/install.sh
```

This creates symlinks so all tools read from the same source:
- `~/.claude/skills/` -> `~/dotfiles/agents/skills/`
- `~/.claude/agents/` -> `~/dotfiles/agents/subagents/`
- `~/.opencode/skills/` -> `~/dotfiles/agents/skills/`
- `~/.opencode/agents/` -> `~/dotfiles/agents/subagents/`
- `~/.agents/skills/` -> `~/dotfiles/agents/skills/`

### Manual Setup

Copy or symlink the directories to your tool's config location:

```bash
# For Claude Code
ln -s ~/dotfiles/agents/skills ~/.claude/skills
ln -s ~/dotfiles/agents/subagents ~/.claude/agents

# For OpenCode
ln -s ~/dotfiles/agents/skills ~/.opencode/skills
ln -s ~/dotfiles/agents/subagents ~/.opencode/agents

# For Agent Skills standard
ln -s ~/dotfiles/agents/skills ~/.agents/skills
```

---

## Creating Skills

### File Structure

Each skill lives in its own directory with a `SKILL.md` file:

```
skills/
└── my-skill/
    ├── SKILL.md           # Required: main instructions
    ├── template.md        # Optional: template for output
    ├── examples/          # Optional: example outputs
    └── scripts/           # Optional: utility scripts
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Display name (defaults to directory name). Lowercase, hyphens only. |
| `description` | Recommended | What the skill does. Used for auto-invocation. |
| `disable-model-invocation` | No | If `true`, only user can invoke via `/name` |
| `user-invocable` | No | If `false`, hidden from slash menu |
| `allowed-tools` | No | Tools available when skill is active |
| `context` | No | Set to `fork` to run in a subagent |
| `agent` | No | Which subagent type when `context: fork` |
| `model` | No | Model override for this skill |

### Invocation Control

| Setting | User can invoke | Model can invoke |
|---------|-----------------|------------------|
| (default) | Yes | Yes |
| `disable-model-invocation: true` | Yes | No |
| `user-invocable: false` | No | Yes |

---

## Creating Subagents

Subagents are Markdown files with YAML frontmatter:

```yaml
---
name: my-agent
description: What this agent does
tools: Read, Grep, Glob, Bash
model: sonnet
permissionMode: default
---

System prompt for the agent goes here.
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Unique identifier (lowercase, hyphens) |
| `description` | Yes | When to use this agent |
| `tools` | No | Available tools (inherits all if omitted) |
| `disallowedTools` | No | Tools to deny |
| `model` | No | `sonnet`, `opus`, `haiku`, or `inherit` |
| `permissionMode` | No | `default`, `acceptEdits`, `dontAsk`, `plan`, `bypassPermissions` |
| `maxTurns` | No | Max agentic iterations |
| `skills` | No | Skills to preload |
| `memory` | No | Persistent memory scope: `user`, `project`, `local` |
| `hooks` | No | Lifecycle hooks |

---

## Permissions

Permissions control what tools agents can use. Configure in settings files:

```json
{
  "permission": {
    "skill": {
      "*": "allow",
      "internal-*": "deny"
    },
    "bash": {
      "*": "ask",
      "git status *": "allow",
      "npm run *": "allow"
    },
    "edit": "ask"
  }
}
```

**Permission values:**
- `allow` - Execute without prompting
- `ask` - Prompt for approval
- `deny` - Block entirely

---

## Tool Compatibility

### OpenCode

Uses `opencode.json` for configuration:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "agent": {
    "build": {
      "mode": "primary",
      "model": "anthropic/claude-sonnet-4-20250514"
    }
  },
  "permission": {
    "skill": { "*": "allow" }
  }
}
```

### Claude Code

Uses `.claude/settings.json`:

```json
{
  "permissions": {
    "allow": ["Bash(npm *)"],
    "deny": ["Bash(rm -rf *)"]
  }
}
```

### Differences

| Feature | OpenCode | Claude Code |
|---------|----------|-------------|
| Primary config | `opencode.json` | `settings.json` |
| Agent teams | Not supported | Supported |
| Sandbox mode | Not documented | OS-level bash sandboxing |
| Plugin system | Yes | Yes |

---

## Best Practices

1. **Keep skills focused** - One skill, one purpose
2. **Write clear descriptions** - The AI uses these to decide when to invoke
3. **Limit tool access** - Grant only what's needed
4. **Use version control** - Commit your skills and agents
5. **Test incrementally** - Start simple, add complexity as needed

---

## Examples

See the `skills/` and `subagents/` directories for working examples:

- `skills/code-reviewer/` - Code quality review
- `skills/debugger/` - Bug diagnosis and fixing
- `skills/explain-code/` - Code explanation with diagrams
- `subagents/researcher.md` - Fast codebase exploration
- `subagents/documentation.md` - Documentation writing

---

## Resources

- [OpenCode Docs - Agent Skills](https://opencode.ai/docs/skills/)
- [OpenCode Docs - Agents](https://opencode.ai/docs/agents/)
- [Claude Code Docs - Skills](https://code.claude.com/docs/en/skills.md)
- [Claude Code Docs - Subagents](https://code.claude.com/docs/en/sub-agents.md)
- [Agent Skills Standard](https://agentskills.io)

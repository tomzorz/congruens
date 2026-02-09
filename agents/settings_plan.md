# Agent Settings Plan

Guidelines for maintaining permissions and settings across agentic tool configurations.

Each tool (OpenCode, Claude Code, etc.) has its own settings format.
This document describes the **shared philosophy** so that when a tool-specific JSON file is updated,
it stays consistent with the others.

---

## Permission Philosophy

### Bash Commands

**Default stance:** `ask` — the agent must request approval for any command not explicitly listed.

**Always allow (read-only, safe):**

- `git status`, `git diff`, `git log`, `git show`, `git branch`, `git tag`, `git stash list`
- `git blame`, `git shortlog`, `git describe`, `git rev-parse`
- `git ls-files`, `git ls-tree`, `git cat-file`
- `git config --get`, `git config --list`
- `git remote -v`, `git remote show`

**Always allow (build / test):**

- `npm run *`, `npm test *`, `npm install`, `npm ci`
- `pnpm *`, `yarn *`, `bun *`
- `cargo build *`, `cargo test *`, `cargo check *`
- `go build *`, `go test *`, `go mod *`
- `python -m pytest *`, `python -m pip install *`, `uv *`
- `dotnet build *`, `dotnet test *`, `dotnet restore *`
- `make *`, `cmake *`

**Always deny (destructive / dangerous):**

- `rm -rf /`, `rm -rf /*`, `rm -rf ~`, `rm -rf ~/*`
- `sudo *`
- `chmod 777 *`
- `curl|wget * | bash|sh` (pipe to shell)
- `eval *`
- Disk-level: `> /dev/sda*`, `mkfs *`, `dd if=*`
- Fork bomb: `:(){:|:&};:`

**Always deny (git destructive):**

- Commits and staging: `git commit`, `git add`
- Branch operations: `git checkout`, `git switch`, `git branch -d/-D/--delete`, `git merge`, `git rebase`
- History rewriting: `git reset`, `git revert`, `git cherry-pick`
- Stash mutations: `git stash` (bare), `git stash drop/pop/clear/push/save`
- Cleanup: `git clean`, `git restore`
- Remote operations: `git push`, `git pull`, `git fetch`, `git clone`
- Repository setup: `git init`, `git rm`, `git mv`
- Tag mutations: `git tag -d/--delete/-a/-s`
- Advanced: `git worktree`, `git submodule`, `git bisect`, `git reflog expire`, `git gc`, `git prune`, `git filter-branch`, `git update-ref`, `git replace`, `git notes`
- Config mutations: `git config --global/--system/--unset`, `git config user.*`
- Remote mutations: `git remote add/remove/rename/set-url`

### File Access

- **Sensitive patterns** (never auto-read): `.env`, `.env.*`, `*.pem`, `*.key`, `*_rsa`, `id_*`, `*.p12`, `*.pfx`, `credentials*`, `secrets*`, `*password*`, `*token*`
- **Read-only patterns**: `node_modules/**`, `.git/objects/**`, `vendor/**`, `dist/**`, `build/**`

### Skills & Subagents

- All skills allowed by default (`*: allow`)
- All subagents allowed by default (`*: allow`)
- Prefix `internal-*` for skills that should be denied in shared contexts

---

## Agent Modes

Two primary modes should be defined:

| Mode | Purpose | Key Restrictions |
|------|---------|------------------|
| **Build** | Default development with full tool access | Standard permissions above |
| **Plan** | Analysis and planning, no modifications | `edit: ask`, bash restricted to read-only git commands |

---

## When Updating Tool-Specific Files

1. **Only add non-default settings** — don't redeclare defaults. If a tool allows all skills by default, don't add `"skill": { "*": "allow" }`.
2. **Keep deny lists in sync** — if you add a new deny rule to one tool's config, add the equivalent to all others.
3. **Translate formats correctly:**
   - OpenCode: `"git status": "allow"` in a `permission.bash` object
   - Claude Code: `"Bash(git status)"` in `permissions.allow` / `permissions.deny` arrays
4. **Test after changes** — verify the tool still starts and respects the new rules.

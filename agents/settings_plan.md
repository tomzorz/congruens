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

**Git posture: middle ground.** Normal forward-moving git work is allowed in config, but agents
ask before `git commit` and `git push` when the user is present (a courtesy defined in AGENTS.md,
not enforced by config). History rewriting and anything that destroys work stays denied. GitHub
branch protection is the real backstop on branches where it matters.

**Allow (forward-moving git):**

- Staging and committing: `git add`, `git commit`
- Branching: `git switch`
- Remote reads: `git fetch`
- Stash forward ops: `git stash` (bare), `git stash push/pop/apply/show`
- Unstaging: `git restore --staged`
- Publishing: `git push` (plain; force/delete/mirror variants stay denied)

**Ask (explicitly listed, so a confirm prompt is guaranteed):**

- `git rebase`. Rewriting history is worth a look before it happens, but denying it outright just pushed the work into `git -C` or a manual reflog dance. A prompt is the honest control here.

**Ask (not listed either way, falls back to the default stance):**

- `git merge`, `git reset` (non-hard), `git revert`, `git cherry-pick`, `git pull`, `git clone`, `git rm`, `git mv`, `git restore` (working tree)
- `git worktree`, `git submodule`, `git bisect`. Previously denied under an "Advanced" bucket with no per-command reason. Worktrees are additive, bisect is a bounded checkout loop that `bisect reset` undoes, and submodule work only bites via `update --force` / `deinit`. None of that earns a hard deny.

**Always deny (git destructive):**

- Legacy branch/checkout: `git checkout` (use switch/restore), `git branch -d/-D/--delete`
- History rewriting: `git reset --hard`, `git filter-branch`, `git update-ref`, `git replace`
- Work destruction: `git stash drop/clear`, `git clean`
- Dangerous pushes: `git push --force*/-f`, `git push --delete`, `git push * :*`, `git push --mirror`
- Repository setup: `git init`
- Tag mutations: `git tag -d/--delete/-a/-s`
- Advanced: `git reflog expire`, `git gc`, `git prune`, `git notes`
- Config mutations: `git config --global/--system/--unset`, `git config user.*`
- Remote mutations: `git remote add/remove/rename/set-url`

**Same speed-bump caveat as `gh` below, and it bites harder here.** These are prefix matches, so `git -C <path> worktree list` sails past a `git worktree *` deny without so much as a prompt (verified). On top of that, Claude Code's built-in worktree tooling never routes through Bash at all, so a `git worktree` deny was only ever stopping the agent from being explicit about what it was doing. Deny the things whose *effect* you cannot live with; use ask for the rest.

### GitHub CLI (`gh`)

**Scope: destructive repo operations and visibility changes only.** Read, PR and issue work through `gh` is untouched and falls back to the default ask stance.

**Always deny (gh destructive):**

- Repo lifecycle: `gh repo delete`, `gh repo archive`, `gh repo unarchive`, `gh repo rename`
- Visibility: `gh repo edit * --visibility*` and `gh repo edit --visibility*`. Two patterns because the repo argument is positional and optional, so a bare invocation from inside a checkout is valid and one pattern misses half the cases.
- REST deletes: `gh api -X DELETE*`, `gh api --method DELETE*`, and both spellings again with a preceding path argument. Without these, denying `gh repo delete` accomplishes nothing, since `gh api -X DELETE repos/OWNER/REPO` does the identical job.
- CI state: `gh secret set/delete`, `gh variable set/delete`. A silent overwrite of a CI secret is miserable to trace back weeks later.
- Published artifacts: `gh release delete`, `gh release delete-asset`
- Keys: `gh ssh-key delete`, `gh gpg-key delete`. Otherwise an agent can lock a machine's own agent keys out of pushing.
- Credentials: `gh auth logout`, `gh auth refresh`, `gh auth token`. Not destructive to GitHub, but the first two mutate stored credentials and their scopes, and `token` prints a live credential to stdout, straight into the session transcript.

**These are prefix matches, so treat them as a speed bump rather than a boundary.** The same work can still be expressed in a shape no pattern anticipated: a REST endpoint that deletes via POST, a GraphQL mutation through `gh api graphql`, or plain `curl` against `api.github.com` with the token pulled from the keyring. Chasing every spelling is not winnable. The real control is the token: keep `delete_repo` off the OAuth scopes (its absence is why `gh repo delete` currently 403s), drop `admin:org` where it is not needed, and for an actual boundary issue a fine-grained PAT scoped to specific repos and hand it to agent sessions via `GH_TOKEN`.

**Left out on purpose:** `gh pr merge*` and `gh workflow run*` are the next candidates if the goal ever widens from "destructive" to "anything with outward effects".

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

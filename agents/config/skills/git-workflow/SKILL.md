---
name: git-workflow
description: |
  How to stand in a git repository before doing anything in it. Tells a
  single-branch repo (one main, always current, commit and push to it)
  from a multi-branch one (base checkout parked on the default branch,
  work in a sibling worktree on a username/kind/description branch cut
  from the latest remote default). Invoke whenever you are about to
  touch a git repo: starting work in one, cloning, branching, committing,
  pushing, or opening a pull request.
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Git Workflow

The shared profile says which git operations are allowed and which are
denied. This skill says where you should be standing when you run them:
which branch, which checkout, cut from what. Run it before the first git
write in a repo, and again if the repo turns out to be a different shape
than you assumed.

## Which shape is this repo

Two shapes, and the answer decides everything below.

**Single-branch.** One branch, usually `main`, that everyone commits to
directly. No pull requests, no long-lived feature branches, no protection
that blocks a direct push. Dotfiles, personal tools, small public repos
with one author.

**Multi-branch.** Work happens on branches and lands through pull requests
or merges. The default branch is protected, or the history shows merges of
named branches, or there are remote branches beyond the default.

How to tell, in order:

1. The repo's own `AGENTS.md` says which shape it is. Believe it.
2. Look: `git branch -r` beyond the default, merge commits in `git log
   --merges -20`, branch protection or open pull requests through the
   host's CLI when one is authenticated.
3. Still unclear: ask the user, and record the answer where this repo
   keeps its rules so nobody asks twice.

Do not guess. A branch pushed to a single-branch repo is clutter; a direct
push to a protected default branch is a rejected push at best.

## Single-branch repos

- **Stay current.** Before any write, `git fetch`, then compare the local
  branch with its upstream. Behind: fast-forward. Diverged: stop and show
  the user both sides; do not merge or rebase on your own. Local commits
  ahead of the remote are fine, that is work waiting to be pushed.
- **One checkout.** No worktrees, no branches. Work on `main`, commit to
  `main`, push `main`.
- **Commit and push** as the profile allows, with the courtesy ask when the
  user is present.

## Multi-branch repos

- **The base checkout stays on the default branch.** Find it from the
  remote (`origin/HEAD`, or the host CLI), not by assuming `main`. If the
  checkout is on some other branch with no changes, switch it back. If it
  has uncommitted work on another branch, that is somebody's in-progress
  state: leave it and ask.
- **Keep the default branch current** the same way as single-branch
  repos: fetch, fast-forward, stop on divergence.
- **Work in a worktree**, never on the base checkout. Worktrees live in a
  sibling folder next to the checkout, one per branch:

  ```
  <repo>/                        the base checkout, on the default branch
  <repo>.worktrees/
    feature-import-retry/        worktree for tomzorz/feature/import-retry
    bug-nul-device/              worktree for tomzorz/bug/nul-device
  ```

  Create the folder with `git worktree add` from the base checkout. When
  the branch has landed and the worktree is no longer needed, remove the
  worktree; deleting the branch is the user's call.

- **Branch names** are `<username>/<kind>/<description>`.
  - `username`: the login on the hosting service. GitHub: `gh api user`.
    A self-hosted host (Gitea, Forgejo, GitLab): the login the CLI or the
    stored credentials are authenticated as. Neither available: ask, and
    record the answer in the repo's rules.
  - `kind`: one of `feature`, `bug`, `task`, `chore`, `spike`, `docs`. A
    piece of work that fits none of them gets asked about; if the user
    names a new kind, add it to this list.
  - `description`: lowercase, hyphenated, a few words that say what the
    branch is for. `import-retry`, not `fix`.

  If the username or the kind is unknown, ask. Do not invent either.

- **Cut from the latest.** A new branch starts from the remote default
  branch after a fetch (`origin/main`, not the local `main`, which may be
  stale), unless the user names another base. Same rule for any branch
  cut from another branch: fetch first, cut from the remote ref.

- **Landing** is a pull request or a merge the user drives. Push the branch
  and stop; do not merge into the default branch yourself.

## Any repo

- Fetch before you decide anything. Every rule above assumes you know what
  the remote looks like right now.
- Fast-forward is the only automatic integration. Anything that would
  create a merge commit or rewrite history is the user's decision.
- The message rules and the allowed and denied operations are in the
  profile and its commit-message skill; this skill does not repeat them.

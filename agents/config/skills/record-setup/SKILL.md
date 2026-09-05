---
name: record-setup
description: |
  Create or revise an area's `AGENTS.records.md`, the map that tells the
  `record` skill where each kind of information gets written in this repo
  or folder tree. Interviews the user branch by branch with the Question
  Tool (scope, hosting and visibility, rules file, docs, decisions,
  diagrams, parked work, spikes, questions, machine facts), writes the
  file beside `AGENTS.md`, and adds the pointer bullet to `AGENTS.md`.
  Use when `record` finds an `AGENTS.md` with no records file beside it,
  or when the user wants to change where things go.
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Record Setup

The `record` skill fixes the vocabulary: every item is a rule, a code fact, a
design, a decision, a finding, a procedure, a diagram, parked work, a
question, a machine fact, or not recorded. This skill fixes the geography:
where each of those goes in one particular area. The answers differ per
area, so they are asked, not assumed.

## When to use this skill

- `record` walked up to an `AGENTS.md` and found no `AGENTS.records.md`
  beside it.
- The user wants to change the answers: a tracker moved, a docs folder
  appeared, the repo went public.
- A new area is being set up and agents will work in it.

## Before the interview

Look, so you can recommend rather than ask blind:

- Confirm the area root: the directory holding the nearest `AGENTS.md` or
  `CLAUDE.md`. If neither exists, the interview starts by asking where the
  root is, and ends by noting that an `AGENTS.md` should exist there.
- Is it a git repo, what is the remote, is it public. `git remote -v` and
  the host's visibility flag if a CLI is available.
- Does `docs/` exist. Are there specs, and in what language. Is there a
  `spikes/` or `sandbox/` folder. Is there a `docs/diagrams/`.
- Is there a next area up: another `AGENTS.md` higher in the tree.

## The interview

Grill-me style: one branch at a time, resolve it, move on. Use the Question
Tool for every round. Put the recommended option first and mark it. End
every round with "Would you like to add anything else?", "No" first, a
free-text path second. The branches, in order:

1. **Scope.** Is the area root what you found? Repo, folder tree, or machine
   root.
2. **Version control and visibility.** Tracked, hosted where, public or
   private. Public settles the machine-fact branch: nothing machine-specific
   goes in.
3. **Rules file.** `AGENTS.md`, `CLAUDE.md`, or both via symlink. Do some
   rules belong to the next area up instead.
4. **Documents.** Where design and procedures go: `docs/`, the README, or
   somewhere the user names. Is there a spec language for normative text.
5. **Decisions and findings.** Inline in the doc they affect, dated
   (recommended). An ADR folder only for teams that already keep one. Where
   does a no-go finding with nothing to inform go: README section
   (recommended) or nowhere.
6. **Diagrams.** `docs/diagrams/` (recommended), another path, or not kept.
   Whatever is chosen overrides the drawing skill's own default location
   for diagrams worth keeping; transient review pages stay where that
   skill puts them.
7. **Parked work.** Issues on the host (recommended when hosted), a named
   external tracker, a TODO comment at the site, or nowhere.
8. **Spikes.** Sandbox folder name, committed or ignored. Reuse an existing
   one if found.
9. **Questions.** Ask the user (recommended), or an `ASSUMPTION:` comment at
   the site when the user is away.
10. **Machine facts.** Where they go for this area: the next area up, a path
    the user names, or nowhere. Public areas get "nowhere" by default.
11. **Not recorded.** Anything to exclude beyond the defaults (progress,
    summaries, anything git already says).

Skip a branch only when the look-around already settled it beyond doubt, and
say that you skipped it and why.

## Write the file

`AGENTS.records.md`, beside `AGENTS.md`. Short: it is a map, not a policy
document. The policy lives in the `record` skill.

```markdown
# Records

Where information produced while working in this area gets recorded.
Read by the `record` skill when it has something to write; created by
`record-setup`. Edit by hand when the answers change.

## Area

- Scope: this repository
- Version control: git, GitHub `owner/repo`, public
- Spec language: none
- Spike sandbox: `spikes/`, committed

## Destinations

| Kind | Where | Notes |
|---|---|---|
| Rule | `AGENTS.md` | Rules that apply beyond this repo go to the next AGENTS.md up. |
| Code fact | Comment at the site | |
| Design | `docs/` | |
| Decision | Inline in the affected doc, dated | |
| Finding | Inline in the doc it informs; README "Things tried" if none | |
| Procedure | `docs/` | |
| Diagram | `docs/diagrams/` | Referenced from the doc it explains. |
| Parked work | GitHub issues | |
| Question | Ask; `ASSUMPTION:` comment when the user is away | |
| Machine fact | Not in this repo | |
| Not recorded | Progress, summaries, anything git already says | |
```

Every kind gets a row, even when the answer is "nowhere", so `record` never
has to guess whether a kind was considered.

## Point AGENTS.md at it

Add one bullet to `AGENTS.md` if it is not already there, in whatever
section holds working rules:

```markdown
- Anything worth keeping past this session goes through the Record skill.
  It reads `AGENTS.records.md` next to this file for where each kind of
  information lives here. "Remember this" and "park this" are always worth
  keeping; anything the code or git history already says never is.
```

That bullet is how every session learns the skill exists. Without it the
records file is a map nobody opens.

If there is no `AGENTS.md`, write the records file anyway and tell the user
the bullet has no home until one exists.

## Finish

Show both files. Do not commit; that is the user's call. If the area still
has a `.agents/` folder from the old system, say so and offer the
`record-triage` skill.

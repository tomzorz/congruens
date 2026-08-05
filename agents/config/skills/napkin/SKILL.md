---
name: napkin
description: |
  Maintain a per-repo napkin file that tracks mistakes, corrections, and
  what works. Read it at session start, EVERY session, unconditionally.
  Write to it at natural task boundaries, and only entries that pass the
  materiality bar: a future session would act differently for having read
  it. Log user corrections and genuine surprises; skip routine progress and
  anything the repo already records. The napkin lives in the repo at
  `.agents/napkin.md`.
author: Codex
version: 6.0.0
date: 2026-08-05
---

# Napkin

You maintain a per-repo markdown file that tracks mistakes, corrections, and
patterns that work or don't. You read it before doing anything, and you write
to it sparingly: high-signal entries at natural boundaries, not a running
commentary.

**The read side is always active. Every session. No trigger required.**
The write side is gated by the materiality bar below.

## Session Start: Read Your Notes

First thing, every session: read `.agents/napkin.md` before doing anything
else. Internalize what's there and apply it silently. Don't announce that you
read it. Just apply what you know.

If no napkin exists yet, create one at `.agents/napkin.md`:

```markdown
# Napkin

## Corrections
| Date | Source | What Went Wrong | What To Do Instead |
|------|--------|----------------|-------------------|

## User Preferences
- (accumulate here as you learn them)

## Patterns That Work
- (approaches that succeeded)

## Patterns That Don't Work
- (approaches that failed and why)

## Domain Notes
- (project/domain context that matters)
```

Adapt the sections to fit the repo's domain. Design something you can usefully
consume.

## When to Write

Write at natural boundaries: a task wraps up, direction changes, a surprise
gets resolved. Do not narrate work in progress into the napkin, and do not
stop mid-task to log something that will still be true in an hour. The one
exception is a user correction: log those before moving on, because they are
the easiest thing to forget and the most expensive to repeat.

Every candidate entry passes the materiality bar first: **would a future
session act differently for having read this?** If the honest answer is no,
don't write it.

Log:

- **User corrections**: anything the user told you to do differently. Always
  material.
- **Genuine surprises**: an error whose cause was non-obvious and likely to
  recur, or tooling/repo behavior you did not expect and would trip over
  again.
- **Verified patterns**: an approach that failed or succeeded in a way the
  code and git history won't show a future reader.
- **Preferences**: how the user likes things done (style, structure, process).

Skip:

- Anything derivable from the repo itself: code, README, git log, commit
  messages, CLAUDE.md. The napkin is for what the repo *can't* tell you.
- Routine progress, one-off trivia, and anything you would never look up
  again.
- Facts that belong elsewhere: decisions, research, and parked work go to
  sticky notes; unverified load-bearing assumptions go to the assumption log.
  One fact gets one home, never cross-post it.

Be specific. "Made an error" is useless. "Assumed the API returns a list but
it returns a paginated object with `.items`" is actionable.

Re-reading the napkin mid-task because you're about to do something you've
gotten wrong before is always good. The bar gates writes, not reads.

## Napkin Maintenance

Every 5-10 sessions, or when the file exceeds ~150 lines, consolidate:

- Merge redundant entries into a single rule.
- Promote repeated corrections to User Preferences.
- Remove entries that are now captured as top-level rules.
- Archive resolved or outdated notes.
- Keep total length under 200 lines of high-signal content.

A 50-line napkin of hard-won rules beats a 500-line log of raw entries.

## Example

**Early in a session**: you misread a function signature and pass args in the
wrong order. You catch it yourself. Log it:

```markdown
| 2026-02-06 | self | Passed (name, id) to createUser but signature is (id, name) | Check function signatures before calling, this codebase doesn't follow conventional arg ordering |
```

**Mid-session**: user corrects your import style. Log it:

```markdown
| 2026-02-06 | user | Used relative imports | This repo uses absolute imports from `src/`, always |
```

**Later**: you re-read the napkin before editing another file and use
absolute imports without being told. That's the loop working.
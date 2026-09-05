---
name: record-triage
description: |
  Sweep an area for leftovers of the retired note-taking system (the
  `.agents/` napkin, sticky notes and assumption logs, plus stray diagram
  dumps) and either route each entry to its proper home through the
  `record` skill or delete it. Presents the whole batch as one table for
  approval before writing anything, then removes the legacy files and the
  empty folder. Use when the user asks to clean up an area's old notes, or
  when `record` reports a `.agents/` folder still present.
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Record Triage

The old system kept a napkin, a folder of sticky notes and a folder of
assumption logs under `.agents/`. Some of what is in there is real: a
correction that should be a rule, a gotcha that should be a code comment, a
decision that should be a dated line in a spec. Most of it is not: progress
notes, resolved tasks, things the code now says. This skill sorts the one
from the other, once, and then the folder is gone.

## When to use this skill

- The user asks to clean up, migrate or triage an area's old notes.
- `record` noticed a `.agents/` folder and the user took the offer.
- A `~/.agent/diagrams/` page clearly belongs to this area and nothing
  references it.

## Precondition

The area needs an `AGENTS.records.md` beside its `AGENTS.md`, because that
is where the destinations come from. If it is missing, run `record-setup`
first, then come back.

## Gather

Find the leftovers under the area root:

- `.agents/napkin.md`
- `.agents/sticky-notes/*.md`
- `.agents/assumptions/*.md`
- Pages in `~/.agent/diagrams/` that are about this area
- Anything else the user names

Split them into entries:

- A napkin table row or bullet is one entry.
- A sticky note or assumption log is one entry, or several when it covers
  several topics. A decision note with three decisions is three entries.
- A diagram page is one entry.

Read every entry in full. This is the one time reading all of it is the job.

## Judge

Give each entry exactly one verdict:

| Verdict | Meaning |
|---|---|
| Route | Still true and material. Name the kind (from `record`) and the destination (from the records file). |
| Already recorded | The rule, comment or doc already exists. Delete. |
| Derivable | The code, README or git history says it. Delete. |
| Stale | No longer true, or the task it parked has been done or abandoned. Delete. |
| Unsure | Cannot tell without the user. Ask. |

Apply the `record` bar strictly. Being in the napkin for six months is not
evidence of value; most napkin entries were written before the bar existed.
When in doubt between Route and Derivable, check whether the thing it
describes is visible in the code today. If it is, Derivable.

Spike sandboxes whose sticky note is being deleted as Stale get the same
verdict. A sandbox whose finding is being routed stays, and the routed
finding links to it.

## Present

Before writing anything, show the whole batch as one table: entry (short),
source file, verdict, and for Route the kind and destination. Four or more
rows means an HTML page through the Visual Explainer, not a markdown table
in chat. Every Unsure row goes through the Question Tool, with the most
likely verdict first, and the round ends with the catch-all question.

Wait for approval. The user may overrule any row.

## Apply

1. Route every approved Route entry through the `record` skill, one at a
   time, in the destination's own form. A napkin correction becomes a
   bullet that reads like the other bullets in `AGENTS.md`. A gotcha becomes
   a comment beside the code it protects.
2. Delete the legacy files and remove `.agents/` once it is empty. Delete
   the triaged diagram pages from `~/.agent/diagrams/`.
3. Search the area for anything that still points at the old locations: a
   README mentioning `.agents/sticky-notes/`, a spike sandbox README, a
   `.gitignore` line. Fix each one.
4. Report what was routed where, what was deleted, and what the user
   overruled. No commit; that is the user's call.

## What this skill does not do

- It does not migrate the old files somewhere else to "keep them just in
  case". Deleted means deleted; git history has them.
- It does not create new destinations. If a Route entry fits no row in the
  records file, that row is an Unsure for the user, not a new file.
- It does not run periodically. Once an area is clean it stays clean,
  because `record` never writes to `.agents/`.

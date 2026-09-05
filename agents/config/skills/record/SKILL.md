---
name: record
description: |
  Persist something worth keeping past this session in the one place a
  human would look for it. Classifies the item into a fixed kind (rule,
  code fact, design, decision, finding, procedure, diagram, parked work,
  question, machine fact, or not recorded), applies the materiality bar,
  and writes it at the destination named in the area's
  `AGENTS.records.md`, in that destination's own form. Use whenever you
  are about to write something down for later: a user correction,
  "remember this", "park this", a spike verdict, a diagram worth keeping,
  or a task-boundary check for anything learned. Replaces the napkin,
  sticky-notes and assumption-log skills.
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Record

Information you learn while working is either important, in which case it
belongs in a structured place a human would look, or it is not, in which
case it is not written down. There is no third place. No scratch file of
lessons, no notes folder, no log that only agents read.

This skill is the routing step. It answers two questions for any item: is it
worth keeping, and if so, where does it go in this area.

## When to use this skill

Invoke it whenever you are about to persist anything beyond the current
conversation:

- The user corrects you, or tells you a preference.
- The user says "remember this", "note that", "park this", "we'll need this
  later". These pass the materiality bar by definition; do not second-guess
  them.
- A spike or piece of research ends with a verdict.
- You made a diagram that a document should reference.
- You discovered something about the code that the code does not say.
- You are about to build on an assumption you cannot verify.
- A task ends. Ask yourself once: did I learn anything that passes the bar?
  Usually the answer is no, and that is the system working.

There is no read side. `AGENTS.md` is loaded by the tools themselves, code
comments and docs are read when you touch them, and the records file is read
only when you have something to write. Do not add a session-start ritual.

## Find the area

Walk up from the working directory to the nearest directory that holds an
`AGENTS.md` or `CLAUDE.md`. That directory is the area, and the records file
is `AGENTS.records.md` beside it.

- Records file present: read it. It is short.
- `AGENTS.md` present, records file missing: invoke the `record-setup` skill,
  which interviews the user and writes it. Then continue.
- No `AGENTS.md` anywhere up to the filesystem root: ask the user where the
  area root is, and suggest an `AGENTS.md` should exist there. Do not guess.

Areas nest. A repo has its own `AGENTS.md`; the folder tree or machine above
it may have another. When an item applies wider than the current area, it
goes to the next area up, through that area's records file.

## The kinds

Every item is exactly one of these. If it is two, it is two items.

| Kind | What it is | Written as |
|---|---|---|
| Rule | How agents must behave here: a correction that generalises, a preference, a workflow step. | One bullet in the rules file, imperative, with the why. It reads like the bullets around it. |
| Code fact | Something true of a specific piece of code that the code does not show: why it is shaped this way, an invariant, a platform gotcha it works around. | A comment at that site, in the style of the comments around it, saying what would break without it. |
| Design | Architecture, interfaces, contracts, data shapes. | A section in the design doc, normative if the area has a spec language. |
| Decision | Chose X over Y, and why. | A dated sentence inside the section it changes. Never a standalone decisions file, never a catch-all "Decisions" section. |
| Finding | Research or spike result with a verdict, including no-go. | A dated paragraph in the doc the finding informs, with the verdict, the reason, and a link to the sandbox if one exists. |
| Procedure | How to do a recurring thing: a runbook, a release step, a recovery. | Steps, in the area's spec language if it has one. |
| Diagram | A picture that explains something recorded: an architecture overview, a flow, a data model. | A self-contained HTML, SVG or Mermaid file named for what it shows, referenced from the doc it explains. |
| Parked work | A concrete future task someone will pick up. | A ticket in the area's tracker, else a TODO comment at the site. Enough context for a cold start. |
| Question | A load-bearing assumption you cannot verify in under a minute. | Ask the user now. If the user is away, an `ASSUMPTION:` comment at the site, and the task summary names it. |
| Machine fact | Paths, hosts, accounts, anything true of one machine. | Wherever the records file says machine facts go for this area. Never inside a public area, not even as an example. |
| Not recorded | Progress, status, summaries of finished work, one-off trivia, anything the code or git history already says. | Nowhere. |

Judgement calls the table does not settle:

- A correction that would not apply again in a different task is not a rule.
  It was a one-off; fix the work and move on.
- An assumption you can settle with a file read, a command, or a search is
  not a question. Settle it and record nothing.
- A finding that changes a rule is recorded as the rule change, with the
  finding as the why. Not both.
- A no-go finding with no doc to inform goes to the README section closest
  to what it would have changed, so nobody tries it again.
- A diagram made to review a diff or a plan is transient. It is not recorded;
  it stays in the tool's scratch location.
- Parked work with no site and no tracker is not concrete enough to park.
  Say so instead of inventing a file for it.

## The bar

Before writing anything, both must be true:

1. A future session, or a new contributor, would act differently for having
   read it.
2. The area does not already say it: not in the code, not in a doc, not in
   `AGENTS.md`, not in git history.

Two yeses or nothing gets written. The user saying "remember this" or "park
this" is two yeses by definition.

## Write it

1. Name the kind.
2. Look up the destination in the records file.
3. Write in the destination's own form. The destination decides the shape:
   a bullet among bullets, a comment among comments, a dated sentence in the
   section it changes. Do not import a template from elsewhere.
4. Never create a new standalone notes file for one item. If the records
   file names no destination that fits, say so and ask the user. Do not
   invent a place.

Timing: a user correction is handled before moving on, because it is the
easiest thing to forget and the most expensive to repeat. Everything else
waits for a natural boundary. Do not stop mid-task to record something that
will still be true in an hour.

## Outward actions

Creating a ticket writes to a tracker other people see. Draft it, show it,
create it only when the user confirms. The same goes for anything else the
records file routes outside the area.

## Legacy

If the area still has a `.agents/` folder with a napkin, sticky notes or
assumption logs, the old system was never cleaned up here. Do not add to it.
Mention it once and offer the `record-triage` skill.

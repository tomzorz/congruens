---
name: sticky-notes
description: |
  Maintain a per-repo folder of sticky note files for capturing deferred work,
  research results, decisions, and any information the developer asks you to
  remember for later. Use this whenever the user asks for something to be done,
  looked up, or decided that will be needed in a future task or session.
  Each note is a separate file in `.agents/sticky-notes/` with a long,
  descriptive filename so agents can find relevant notes by scanning titles
  without reading every file.
author: congruens
version: 2.0.0
date: 2026-02-20
---

# Sticky Notes

You maintain a per-repo folder of individual markdown files, each capturing
one topic the developer (or you) wants preserved for later use. This is not a
log of mistakes (that is the Napkin); this is a deliberate parking lot for
deferred work, research findings, architectural decisions, reminders, and
anything else that needs to survive beyond the current session.

Each note is its own file so agents can scan filenames and only read the ones
relevant to the task at hand.

## When to Use This Skill

Use sticky notes whenever:

- **The user says "remember this"**, "save this for later", "we'll need this",
  or anything that signals deferred intent.
- **You produce research or analysis** that the user will need in a future task
  (API comparisons, library evaluations, architecture options).
- **A decision is made** that future sessions should know about (e.g. "we chose
  Polly over custom retry logic because...").
- **A task is deferred**. The user says "not now, but later" or "park this".
  Capture enough context that a cold-start session can pick it up.
- **You discover something incidentally** while working on something else, like
  a performance concern, a TODO worth revisiting, or a dependency that needs
  an upgrade, and the user confirms it should be tracked.

Do not use sticky notes for mistakes or corrections (use the Napkin for those).

## Folder Structure

Notes live in `.agents/sticky-notes/`. Each note is a separate `.md` file.
Create the directory if it does not exist.

```
.agents/
  sticky-notes/
    2026-02-20-rate-limiter-comparison-aspnetcoreratelimit-vs-builtin-dotnet7.md
    2026-02-20-deferred-n-plus-1-query-in-orderservice-getall-refactor-after-release.md
    2026-02-20-decision-chose-polly-over-custom-retry-for-http-resilience.md
```

## File Naming Convention

Filenames are the primary discovery mechanism. Make them long and meaningful
so a future agent (or human) can decide whether to open the file just by
reading the name.

Format: `YYYY-MM-DD-<descriptive-slug>.md`

Rules for the slug:

- Use lowercase kebab-case.
- Be specific and verbose. Aim for 8-15 words. A title that is too short
  forces the reader to open the file to figure out if it is relevant.
- Include the domain, the subject, and the intent or action.
- Front-load the most distinguishing terms so alphabetical and glob listings
  are scannable.

Good filenames:

- `2026-02-20-rate-limiter-comparison-aspnetcoreratelimit-vs-builtin-dotnet7.md`
- `2026-02-20-deferred-n-plus-1-query-in-orderservice-getall-refactor-after-release.md`
- `2026-02-20-decision-chose-polly-over-custom-retry-for-http-resilience.md`
- `2026-02-20-reminder-upgrade-newtonsoft-to-system-text-json-before-net9-migration.md`
- `2026-02-20-research-blob-storage-options-azure-vs-s3-vs-minio-for-document-service.md`

Bad filenames:

- `2026-02-20-notes.md` (says nothing)
- `2026-02-20-research.md` (research about what?)
- `2026-02-20-todo.md` (which todo?)

## File Content Template

Each file should follow this structure:

```markdown
# <Title matching the filename in natural language>

**Date**: YYYY-MM-DD
**Category**: research | decision | deferred-task | reminder
**Status**: open | done

## Context

Why this note exists. Enough background that a cold-start session or a
different agent can understand it without re-reading any conversation.

## Content

The actual research result, decision rationale, deferred task description,
or reminder. Be concise but self-contained.

## Action / Next Steps

What should happen with this information and when.
```

Adapt the sections to fit the note. Not every note needs every section. A
two-line reminder does not need a full Context block, but a research
comparison definitely does.

## Reading Sticky Notes

At session start, list the files in `.agents/sticky-notes/` (if the directory
exists) alongside reading the Napkin. Scan the filenames. Only open files
whose titles look relevant to the current task. Don't read every file, and
don't announce that you scanned them.

When picking up a deferred task, scan sticky note filenames first; the context
you need is probably already there.

## Writing Sticky Notes

Write a note as soon as the information is produced or the deferral happens.
Don't wait until the end of the session. One topic per file.

If a topic grows or evolves across sessions, update the existing file rather
than creating a duplicate. If the scope shifts significantly, create a new
file and delete or mark the old one as done.

## Completing & Cleaning Up

When a sticky note has been acted on:

- Delete the file, or set its `Status` to `done` if you want to keep the
  record around briefly.
- If a deferred task turned into actual work, delete the note; the code and
  commits are the record now.

Every few sessions, scan the folder and prune notes that are stale, resolved,
or already captured elsewhere. A lean folder of 5-10 high-signal notes beats
a graveyard of 50 outdated ones.

## Examples

### Research note

**Filename**: `2026-02-20-rate-limiter-comparison-aspnetcoreratelimit-vs-builtin-dotnet7.md`

```markdown
# Rate limiter comparison: AspNetCoreRateLimit vs built-in .NET 7

**Date**: 2026-02-20
**Category**: research
**Status**: open

## Context

We need rate limiting on the public API. User asked to evaluate options but
not add anything yet.

## Content

Compared AspNetCoreRateLimit (NuGet, 12M downloads) vs the built-in
`Microsoft.AspNetCore.RateLimiting` middleware (.NET 7+).

Built-in wins for our case: fewer dependencies, native DI integration,
good enough for our scale (~500 rps). AspNetCoreRateLimit has more granular
IP-based policies but that is overkill here.

Source: https://learn.microsoft.com/en-us/aspnet/core/performance/rate-limit

## Action / Next Steps

Add the built-in rate limiter when we start the API hardening sprint
(post-release).
```

### Deferred task note

**Filename**: `2026-02-20-deferred-n-plus-1-query-in-orderservice-getall-refactor-after-release.md`

```markdown
# Deferred: N+1 query in OrderService.GetAll(), refactor after release

**Date**: 2026-02-20
**Category**: deferred-task
**Status**: open

## Context

Found during perf review of the orders page. Each call to GetAll() fires one
query per order to load line items. Current load (~200 orders) keeps response
under 400ms so it is not blocking the release.

## Content

Refactor OrderService.GetAll() to use a single joined query or a batched
fetch (EF Include or split query). Expected to cut response time by ~60%
at current volume and prevent it from becoming a problem as order count grows.

## Action / Next Steps

Pick this up in the first sprint after the v2.4 release.
```

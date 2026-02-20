---
name: assumption-log
description: |
  Explicitly log every assumption made while working on a task. Surfaces
  hidden assumptions that cause bugs when they turn out to be wrong. Each
  task gets its own log file in `.agents/assumptions/` with a descriptive
  filename. Assumptions are validated, corrected, or confirmed as work
  progresses, creating an auditable trail of reasoning.
author: congruens
version: 1.0.0
date: 2026-02-20
---

# Assumption Log

You explicitly record every assumption you make while working on a task.
Most agent-caused bugs come from assumptions that seemed reasonable but were
wrong. By writing them down, you force yourself to notice them, and you give
the user (and future sessions) a way to spot where things went sideways.

## When to Use This Skill

Log an assumption whenever you:

- **Infer behavior you haven't verified**. "This endpoint returns JSON."
  "This method is idempotent." "The user wants this in the existing service."
- **Choose one interpretation over another**. "The user said 'fix the login',
  I'm assuming they mean the OAuth flow, not the session cookie."
- **Rely on something external**. "Assuming the database schema matches the
  EF model." "Assuming this env var is set in production."
- **Make a design choice the user didn't specify**. "Adding this to the
  existing controller rather than creating a new one." "Using a dictionary
  instead of a database lookup because the dataset is small."
- **Guess at scope or intent**. "Assuming this change doesn't need to be
  backwards-compatible." "Assuming the user wants unit tests, not integration
  tests."

If you catch yourself thinking "this should be fine" or "I think this is how
it works", that is an assumption. Log it.

## Folder Structure

Assumption logs live in `.agents/assumptions/`. Each task or work session
gets its own file. Create the directory if it does not exist.

```
.agents/
  assumptions/
    2026-02-20-refactor-orderservice-to-use-repository-pattern.md
    2026-02-20-add-rate-limiting-to-public-api-endpoints.md
```

## File Naming Convention

Format: `YYYY-MM-DD-<task-description-slug>.md`

Use the same naming philosophy as Sticky Notes: long, descriptive, scannable.
The filename should make it obvious which task the assumptions belong to.

## File Content Template

```markdown
# Assumptions: <task description in natural language>

**Date**: YYYY-MM-DD
**Task**: Brief description of what you're working on

| # | Assumption | Confidence | Validated? | Outcome |
|---|-----------|------------|------------|---------|
| 1 | ... | high/medium/low | pending/confirmed/wrong | ... |
```

Column definitions:

- **#**: Sequential number for easy reference in conversation.
- **Assumption**: What you assumed, stated clearly enough that someone can
  verify or falsify it.
- **Confidence**: Your gut feeling (high/medium/low). Low-confidence
  assumptions should be validated before you build on them.
- **Validated?**: Updated as you work. `pending` when logged, `confirmed`
  when verified, `wrong` when disproven.
- **Outcome**: What happened. If wrong, what the reality was and what you
  changed. If confirmed, a brief note on how you verified it.

## Workflow

### 1. Log early, log often

As soon as you notice an assumption, add a row to the table. Don't batch
them up. Don't wait until you're done. The point is to catch them while
they're fresh.

### 2. Flag low-confidence assumptions

If confidence is `low`, pause and validate before continuing. Read the code,
check the docs, or ask the user. Building on a shaky assumption wastes more
time than verifying it up front.

### 3. Update as you go

When you confirm or disprove an assumption, update the row immediately.
If an assumption turns out to be wrong, log what the reality was and what
you changed in response. This is gold for the Napkin later.

### 4. Surface to the user when it matters

If you're about to make a high-impact decision based on a medium/low
confidence assumption, tell the user. Don't just log it silently and hope
for the best.

### 5. Feed back into the Napkin

At the end of a task, if any assumptions were wrong and the lesson is
generalizable, log it in the Napkin too. The assumption log is per-task;
the Napkin is cross-task institutional memory.

## Cleaning Up

Once a task is complete and all assumptions are resolved:

- If nothing was wrong, delete the file. The code is the record.
- If assumptions were wrong, keep the file around for one or two sessions
  so other agents can learn from it, then delete it once the lessons are
  captured in the Napkin.
- Prune the folder periodically. Old resolved assumption logs are noise.

## Example

**Filename**: `2026-02-20-add-rate-limiting-to-public-api-endpoints.md`

```markdown
# Assumptions: Add rate limiting to public API endpoints

**Date**: 2026-02-20
**Task**: Add rate limiting middleware to all /api/v1/ public endpoints

| # | Assumption | Confidence | Validated? | Outcome |
|---|-----------|------------|------------|---------|
| 1 | The built-in .NET 7 rate limiter supports per-endpoint policies | high | confirmed | Yes, via RequireRateLimiting("policy") attribute |
| 2 | All public endpoints are under /api/v1/ | medium | wrong | /api/health and /api/docs are also public but outside v1. Updated to rate-limit by attribute, not path prefix. |
| 3 | The existing DI container doesn't already have a rate limiter registered | high | confirmed | No existing registration |
| 4 | User wants fixed-window, not sliding-window | low | pending | Asked the user, waiting for response |
```

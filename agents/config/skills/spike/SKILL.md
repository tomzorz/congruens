---
name: spike
description: |
  Run a structured, timeboxed technical exploration when facing an unknown.
  Define the question, set a timebox, explore, and record findings with a
  clear go/no-go recommendation. Prevents yak-shaving by forcing a bounded
  investigation with a decisive outcome. Spike code lives in a dedicated
  sandbox folder in the repo so proof-of-concept work is preserved and
  reviewable. Results are saved as sticky notes for future reference.
author: congruens
version: 2.0.0
date: 2026-02-20
---

# Spike

A spike is a short, focused investigation into a technical unknown. You use
it when you don't know if something will work, which approach is best, or
whether a dependency/API/pattern fits the problem, and guessing would be
reckless.

The whole point is to prevent two failure modes:
1. **Guessing wrong** and building on a bad foundation.
2. **Yak-shaving** and spending 45 minutes exploring when 10 would have
   answered the question.

A spike has a question, a timebox, an investigation, and a verdict. Always.

## When to Use This Skill

Use a spike when:

- **You're about to adopt a library or API you haven't used before** and you
  need to verify it actually does what you think it does.
- **There are multiple viable approaches** and you need to compare them
  concretely, not just theoretically.
- **The user asks "can we do X?"** and you genuinely don't know without
  trying it.
- **You hit a wall** and you're not sure if the current approach is fixable
  or if you need to pivot.
- **A low-confidence assumption** in your assumption log needs validation and
  reading docs alone won't cut it; you need to try something.

Do NOT use a spike for things you can answer by reading docs or code. If the
answer is in the source, just go read it.

## Sandbox Folder

Spike code (proof-of-concepts, throwaway scripts, test harnesses) lives in a
dedicated sandbox folder in the repo. This keeps spike work out of production
code while preserving it for reference, review, and potential reuse.

### Locating the sandbox

Some repos already have a sandbox folder. Common names and locations:

- `sandbox/`
- `spikes/`
- `.spikes/`
- `experiments/`
- `_sandbox/`
- `scratch/`

At the start of a spike, check if any of these directories exist in the repo
root. If you find one, use it. If multiple exist, pick the one that looks
most active or conventional for the project.

### If no sandbox folder exists

**Ask the user.** Do not create the folder silently. The user needs to decide:

- Where it should live (repo root? a subdirectory?).
- What it should be called.
- Whether it should be gitignored (some teams want spike code committed for
  review, others want it ephemeral).

Example prompt: "This repo doesn't have a sandbox folder for spike code yet.
Where would you like me to create one? (e.g. `spikes/`, `sandbox/`,
`.spikes/`). Also, should it be gitignored or committed?"

Once the user answers, create the folder and optionally add a one-line
README so its purpose is obvious to other contributors:

```markdown
# Spikes

Throwaway proof-of-concept code from timeboxed technical investigations.
Not production code. See `.agents/sticky-notes/` for spike findings.
```

### Organizing spike code in the sandbox

Each spike gets its own subfolder named with the same slug as the sticky note:

```
spikes/
  2026-02-20-signalr-realtime-notifications/
    Program.cs
    README.md
  2026-02-20-rate-limiter-per-user-policies/
    test.http
    RateLimitTest.cs
```

Rules:

- **One subfolder per spike.** Don't dump loose files in the sandbox root.
- **Name the subfolder with `YYYY-MM-DD-<slug>`** matching the sticky note
  filename. This makes it trivial to cross-reference findings with code.
- **Include a README.md** in the subfolder if the spike involves more than
  one file. Explain what to run and what to look at. Keep it brief.
- **Don't polish the code.** This is throwaway work. Comments are fine,
  tests are optional, formatting is whatever. The point is answering the
  question, not shipping the code.
- **Don't reference sandbox code from production code.** If the spike
  graduates to real implementation, copy the relevant parts into the actual
  project and delete or archive the spike subfolder.

## Spike Protocol

### 1. Define the question

Write down the exact question you're trying to answer. One question per spike.
If you have three questions, run three spikes (or acknowledge you're combining
them, and set the timebox accordingly).

Good spike questions:
- "Can the built-in .NET rate limiter do per-user policies with a custom key?"
- "Does the Stripe SDK support idempotency keys on subscription updates?"
- "Is it faster to use a CTE or a temp table for this 3-join aggregation?"

Bad spike questions:
- "How does rate limiting work?" (too vague, go read the docs)
- "What should our architecture be?" (too big, not a spike)

### 2. Locate (or create) the sandbox

Check for an existing sandbox folder. If none exists, ask the user before
proceeding (see "Sandbox Folder" above). Do not skip this step.

### 3. Set a timebox

Decide how long you'll spend before you must stop and report. Default: **10
minutes**. Adjust based on complexity but never exceed **20 minutes**. If you
can't answer it in 20 minutes, the question is too big; break it down.

State the timebox explicitly when you start.

### 4. Investigate

Do the minimum work necessary to answer the question:

- Read docs, source code, or type definitions.
- Write proof-of-concept code in the sandbox subfolder.
- Test a single specific thing, not the whole integration.
- Search the web for known issues or gotchas.

Stay focused. If you discover an interesting tangent, note it and come back
to it later (use a Sticky Note). Do not follow the tangent during the spike.

All code artifacts go in the sandbox subfolder. Do not write spike code in
the main source tree, temp directories, or inline in the sticky note.

### 5. Record findings and verdict

When the timebox expires (or you have your answer, whichever comes first),
write up the result. The spike output is saved as a **Sticky Note** in
`.agents/sticky-notes/` so it persists across sessions. The sticky note
links back to the sandbox subfolder for the code.

## Spike Output Format

Save as a sticky note with a filename like:
`YYYY-MM-DD-spike-<question-slug>.md`

```markdown
# Spike: <question in natural language>

**Date**: YYYY-MM-DD
**Category**: research
**Status**: open
**Timebox**: X minutes
**Time spent**: Y minutes
**Sandbox**: <relative path to spike subfolder, e.g. spikes/2026-02-20-signalr-realtime-notifications/>

## Question

The exact question this spike set out to answer.

## Findings

What you discovered. Be specific: code snippets, API responses, error
messages, doc quotes. Enough that someone can trust your conclusion without
re-running the spike.

Reference specific files in the sandbox when relevant (e.g. "see
`spikes/2026-02-20-signalr-realtime-notifications/Program.cs:42`").

## Verdict

**Go** / **No-go** / **Needs more investigation**

One sentence: what should we do based on these findings?

## Caveats & Open Questions

Anything you didn't have time to verify, edge cases you noticed but didn't
test, or follow-up questions that emerged.
```

## Communicating with the User

- **Before starting**: Tell the user you're running a spike, what the question
  is, and what the timebox is. One sentence, not a ceremony.
- **After finishing**: Share the verdict and a one-line summary. Point them to
  the sticky note and sandbox subfolder if they want details.
- **If inconclusive**: Say so honestly. "I spent 10 minutes and couldn't
  confirm X. Here's what I found. Want me to spend more time or try a
  different angle?"

## Spike Lifecycle & Cleanup

Spike sandbox subfolders follow the same lifecycle as their sticky notes:

- **While the sticky note is open**: keep the sandbox subfolder. Someone
  might want to re-run or extend the proof-of-concept.
- **When the spike is acted on** (the approach is adopted into production
  code): delete the sandbox subfolder. The production code is the record now.
- **When the spike is abandoned** (verdict was no-go and the team has moved
  on): delete the sandbox subfolder or leave it if it has historical value.
  Use your judgment.
- **Periodic pruning**: when you prune stale sticky notes, prune the matching
  sandbox subfolders too. Don't leave orphaned spike code lying around.

## Integration with Other Skills

- **Assumption Log**: If a spike was triggered by a low-confidence assumption,
  update the assumption log row with the spike result.
- **Sticky Notes**: Spike results ARE sticky notes. They use the same folder
  and follow the same lifecycle (delete when acted on, prune when stale).
- **Napkin**: If the spike reveals a non-obvious gotcha or pattern, log it in
  the Napkin for long-term memory.

## Example

**User**: "Can we use SignalR for the real-time notifications or do we need
a separate WebSocket server?"

**Agent says**: "Running a spike on this, 10-minute timebox."

**Agent checks**: Finds `spikes/` directory exists in the repo root. Creates
`spikes/2026-02-20-signalr-realtime-notifications/`.

**Agent investigates**: Reads SignalR docs, writes a minimal hub + client in
the sandbox subfolder, checks the existing project for compatible
dependencies, verifies the hosting model supports WebSockets.

**Sandbox contents**:
```
spikes/2026-02-20-signalr-realtime-notifications/
  NotificationHub.cs       # minimal hub, 20 lines
  test-client.html         # browser client to verify connection
  README.md                # "run with: dotnet run, open test-client.html"
```

**Sticky note saved as**:
`2026-02-20-spike-can-signalr-handle-realtime-notifications-without-separate-websocket-server.md`

```markdown
# Spike: Can SignalR handle real-time notifications without a separate WebSocket server?

**Date**: 2026-02-20
**Category**: research
**Status**: open
**Timebox**: 10 minutes
**Time spent**: 7 minutes
**Sandbox**: spikes/2026-02-20-signalr-realtime-notifications/

## Question

Can we use ASP.NET SignalR for the real-time notification feature, or do we
need a standalone WebSocket server?

## Findings

- The project already targets .NET 7, which has SignalR built in. No extra
  NuGet needed.
- SignalR supports WebSockets, SSE, and long-polling as transports, with
  automatic fallback.
- The existing Kestrel config in Program.cs doesn't disable WebSockets, so
  it should work out of the box.
- Minimal hub + browser client working in the sandbox (see
  `spikes/2026-02-20-signalr-realtime-notifications/NotificationHub.cs`).
- Scaling concern: with multiple app instances, we'd need a backplane (Redis
  or Azure SignalR Service). Currently single-instance, so not an issue yet.

## Verdict

**Go**. SignalR fits. No separate server needed for current scale.

## Caveats & Open Questions

- If we scale to multiple instances, we'll need a Redis backplane. Not
  blocking, but worth a sticky note for later.
- Haven't tested auth integration with the existing JWT middleware, but the
  docs say it's supported via query string token for WebSocket connections.
```

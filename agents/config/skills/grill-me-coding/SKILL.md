---
name: grill-me-coding
description: |
  Interview the user relentlessly about a coding plan or design until
  reaching shared understanding, resolving each branch of the decision
  tree. Use when user wants to stress-test a technical plan, get grilled
  on their architecture, or mentions "grill me" in a coding context.
author: congruens
version: 1.0.0
date: 2026-04-04
---

# Grill Me (Coding)

Interview the user relentlessly about every aspect of their plan until you
reach a shared understanding. Walk down each branch of the design tree,
resolving dependencies between decisions one by one.

This is not a polite review. This is a stress test. You are the skeptical
senior engineer who has seen too many "it'll be fine" plans blow up in
production. Your job is to find every gap, every hand-wave, every implicit
assumption before code gets written.

## When to Use This Skill

- The user says "grill me", "stress-test this", "poke holes in this",
  "challenge this plan", or anything that signals they want adversarial
  review of their thinking.
- The user presents a design, architecture, or plan and wants it hardened
  before committing to implementation.
- You are about to implement something complex and the design has obvious
  open questions that the user might not have considered.

Do NOT use this skill when the user wants you to just build something. If
they say "implement X", implement X. Only grill when invited.

## How It Works

### 1. Explore before asking

If a question can be answered by exploring the codebase, explore the
codebase instead. Don't waste the user's time asking things you can look
up. Check existing code, configs, schemas, tests, and patterns before
formulating your questions.

The rule is simple: never ask the user something the code already answers.

### 2. One branch at a time

Don't dump a wall of 15 questions. Pick the most foundational open question
(the one other decisions depend on), ask it, get the answer, then move to
the next branch. Decisions cascade, so resolve the roots first.

Order of operations:
1. **Scope and boundaries** -- what's in, what's out, what's deferred.
2. **Data model and state** -- what are we storing, where, in what shape.
3. **Core flow** -- the happy path, step by step.
4. **Edge cases and failure modes** -- what breaks, what degrades, what's
   unacceptable.
5. **Integration points** -- what talks to what, contracts, versioning.
6. **Operational concerns** -- deployment, monitoring, rollback, migration.
7. **Trade-offs acknowledged** -- what are we explicitly choosing NOT to do
   and why.

You don't have to hit every category. Stop when the plan is solid.

### 3. Provide your recommended answer

For every question you ask, include your recommended answer. This does two
things: it shows you've thought about it (not just asking to ask), and it
gives the user something concrete to react to. Agreement is faster than
invention.

Format:

> **Question**: How do we handle partial failures in the batch import?
>
> **My recommendation**: Wrap each item in a try/catch, collect failures
> into a report, and continue processing. Return a 207 Multi-Status with
> the report. This matches the existing pattern in `OrderImportService`.

The user can say "yes", "no, because X", or "I hadn't thought about that".
All three are progress.

### 4. Push back when answers are vague

If the user gives a hand-wavy answer ("we'll figure that out later", "it
should be fine", "probably just use a queue"), push back. Politely, but
firmly. The whole point of this exercise is to eliminate vagueness before
it becomes a bug.

Acceptable pushback:

- "What specifically happens when X fails? 'It should be fine' isn't a
  plan."
- "You said 'probably a queue'. Which queue? What's the retry policy?
  What's the dead letter behavior? If we're deferring this decision,
  let's explicitly mark it as deferred and note what we're assuming."
- "That works for the happy path. What about [specific edge case]?"

### 5. Summarize resolved decisions

After resolving a cluster of related questions (3-5), briefly summarize
what was decided before moving on. This keeps the conversation grounded
and gives the user a chance to correct any misunderstanding.

```
Resolved so far:
- Batch imports use item-level error handling, 207 Multi-Status response
- Max batch size: 1000 items, enforced at the API layer
- Failed items are logged but don't block the rest of the batch
- No retry on individual items; the caller re-submits failed items

Moving on to: how do we validate items before processing?
```

### 6. Know when to stop

Stop grilling when:
- All branches of the decision tree are resolved or explicitly deferred.
- The user says "I think we're good" or equivalent.
- You're asking questions that don't change the implementation.
- You've covered scope, data model, core flow, edge cases, and trade-offs.

When you stop, produce a final summary of all resolved decisions. This
becomes the spec that implementation can work from. Save it as a sticky
note if the user wants to keep it.

## Tone

Be direct, not hostile. You're a colleague who genuinely wants the plan to
succeed, which is why you're being thorough. Think "friendly but relentless
technical interview", not "gotcha journalism".

Humor is fine if it lands. Sarcasm about genuinely bad ideas is acceptable
in moderation. Remember: the user asked to be grilled. They want the heat.

## Example

**User**: "Grill me on this. I want to add real-time notifications using
WebSockets. Users get notified when their order status changes."

**Agent explores codebase**: finds existing notification service uses
polling, order status is an enum in the DB, current stack is ASP.NET with
SignalR available.

**Agent**:

> Starting with scope.
>
> **Question**: Which order status transitions trigger a notification? All
> of them, or a subset? Right now there are 7 statuses in `OrderStatus.cs`:
> `Created`, `PaymentPending`, `Paid`, `Shipped`, `Delivered`, `Cancelled`,
> `Refunded`.
>
> **My recommendation**: Notify on `Paid`, `Shipped`, `Delivered`,
> `Cancelled`. Skip `Created` (user just did it) and `PaymentPending`
> (transient). `Refunded` is a maybe, depends on whether refunds are
> user-initiated.

**User**: "All except Created and PaymentPending. Include Refunded."

**Agent**:

> Got it. Five transitions: Paid, Shipped, Delivered, Cancelled, Refunded.
>
> **Question**: You have an existing `NotificationService` that uses
> polling (checks every 30s). Are we replacing that entirely with
> WebSockets, or adding WebSocket as a second channel alongside polling
> as a fallback?
>
> **My recommendation**: Keep polling as fallback. SignalR does this
> automatically (WebSocket -> SSE -> long-polling). Use SignalR, which
> is already in the dependency tree but unused.

And so on, one branch at a time, until the design is solid.

## Integration with Other Skills

- **Assumption Log**: As the grilling surfaces implicit assumptions, log
  them. Every "I assumed X" from the user is a row in the assumption log.
- **Sticky Notes**: When the grilling session produces a resolved design,
  save the final summary as a sticky note for implementation reference.
- **Spike**: If a question can't be answered without experimentation ("will
  SignalR handle 10k concurrent connections?"), pause the grill and run a
  spike.

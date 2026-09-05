---
name: socratic-press
description: |
  Stress-test a plan, design or idea by interviewing the user branch by
  branch until every decision is resolved or explicitly deferred. Research
  before asking, roots before leaves, one Question Tool round at a time
  with a recommendation first, pushback on vague answers, and a decisions
  document in the user's voice at the end. Works for code (explores the
  codebase) and for anything else (explores docs and the web). Use when
  the user says "grill me", "stress-test this", "poke holes", "challenge
  this plan", or presents a plan they want hardened before acting on it.
  One of three socratic-* skills; the others are socratic-pull and
  socratic-reflect.
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Socratic Press

Interview the user relentlessly about their plan until you both understand
it the same way. Walk each branch of the decision tree, resolve the roots
first, and do not accept "it'll be fine" as an answer. You are the
colleague who has seen this go wrong before and would rather find the gap
now than in production.

## When to use this skill

- The user says "grill me", "stress-test this", "poke holes in this",
  "challenge this", or presents a plan and wants it hardened.
- You are about to build something complex and the design has open
  questions the user has not considered.

Do not use it when the user says "implement X". Implement X. Grill only when
invited. Do not use it when there is no plan yet, only a feeling; that is
`socratic-pull`, and the hand-off below covers the case where you find that
out mid-grill.

## Before the first question

### Research first

Never ask what you can find out. If there is a codebase, read the code,
configs, schemas, tests and existing patterns. If there is not, read the
docs, the data the user gave you, and the web. The user's time is for the
questions only the user can answer.

### Prior thinking

Look for earlier output on the topic before asking anything: a decisions
document from a previous grill, a design note, a vault or project note. If
one exists, build on it rather than re-asking. Refer to it loosely and with
its date ("in July you settled on X"); the user may have changed their mind
since, so treat it as a starting position, not a constraint.

## How it works

### One branch at a time

Do not dump fifteen questions. Pick the most foundational open question,
the one other decisions depend on, resolve it, then move to the next.
The order, adapted to the domain:

1. **Goal and success criteria.** What does done look like, measured how.
2. **Scope and boundaries.** What is in, what is out, what is deferred.
3. **Assumptions.** What is being taken for granted, and what if it is wrong.
4. **Core mechanism.** The happy path step by step. For code: data model
   and state, what is stored where and in what shape.
5. **Failure modes.** What breaks, what degrades, what is unacceptable. For
   code: edge cases.
6. **Dependencies and sequencing.** What talks to what, contracts,
   versioning, what has to happen first.
7. **Resources and operations.** Time, money, people, tools. For code:
   deployment, monitoring, rollback, migration.
8. **Trade-offs acknowledged.** What is explicitly not being done, and why.

Not every category applies. Stop when the plan is solid.

### Question Tool, recommendation first

Every question goes through the Question Tool. The first option is your
recommendation, marked as such, so the user has something concrete to
react to: agreement is faster than invention. The remaining options are
the genuine alternatives. Every round ends with the catch-all question,
"No" first and a free-text path second. A recommendation shows you thought
about it; it is not the answer until the user picks it.

### Label the answer, then follow it

Read each answer as one of: agree, disagree, question, suggestion,
confused, error, info, action. The label decides the next move:

| Label | Next move |
|---|---|
| agree | Record it, move on. |
| disagree | Ask why, once. The reason is the decision. |
| question | Answer it from research before continuing; if research cannot, mark it as an open question. |
| suggestion | Take it as the candidate answer and test it the way you would have tested yours. |
| confused | Rephrase the question with a concrete example. Do not push. |
| error | You got a fact wrong. Correct it, check what else it touched. |
| info | New fact from the user. Fold it in; it may reorder the branches. |
| action | The user wants something done, not asked. Do it, or park it, then resume. |

### Push back on vagueness

"We'll figure that out later", "it should be fine", "probably a queue" are
not answers. Ask what specifically happens, which one, with what policy.
If the user wants to defer, fine: mark it deferred, with the assumption the
plan makes in the meantime, so the deferral is a decision and not a gap.

### Explicit agreement only

A recommendation you offered enters the resolved list only when the user
said yes to it. Silence, a topic change, or "sure, whatever" is not
agreement; ask again or mark it open. The decisions document is the user's,
not yours.

### Recap every few decisions

After three to five related decisions, list what was resolved and name the
next branch. This keeps the conversation grounded and gives the user a
place to correct a misunderstanding early.

### Hand off when there is no plan

If the first answers show the idea is not formed yet (every question gets
"I don't know" or a restatement of the goal), say so and hand over to
`socratic-pull`. Grilling fog produces confident-sounding decisions about
nothing. Come back to the grill when the idea is out.

### Pause for experiments

If a question cannot be answered without trying something ("will this
handle ten thousand connections"), pause the grill, settle it with a
timeboxed experiment, and resume with the result.

### Know when to stop

Stop when every branch is resolved or explicitly deferred, when the user
says "we're good", or when your questions stop changing the plan.

## The decisions document

When the grill ends, write down what was decided:

- In the user's voice ("we will", "I am not doing X because"), using their
  wording wherever it can stand.
- Only what the user said or explicitly agreed to. Your unaccepted
  recommendations are not in it. Open and deferred items are listed as such,
  each with the assumption made in the meantime.
- Complete, not summarised, with no adjectives that characterise the plan
  and no preamble. A short grill gives a short document.

Before showing it, check every line against the conversation: anything the
user did not say or agree to comes out, anything they decided that is
missing goes in.

Put the document where this area keeps designs and decisions. If that is
not obvious, ask. Turning it into a normative spec is a separate step the
user asks for. A later session can walk it claim by claim with
`socratic-reflect`.

## Tone

Direct, not hostile. Friendly but relentless technical interview, not
gotcha journalism. Humour if it lands; the user asked for the heat.

## Example

**User**: "Grill me on this. Real-time order notifications over
WebSockets."

**Agent** reads the codebase: the existing notification service polls every
30 seconds, order status is a seven-value enum, the stack is ASP.NET with
SignalR in the dependency tree but unused. No earlier decisions document on
the topic.

**Agent**, first round, Question Tool: which status transitions notify.
Recommended option first: Paid, Shipped, Delivered, Cancelled; Created and
PaymentPending skipped as the user's own action and transient; Refunded
open. Alternatives: all seven; a configurable set. Catch-all last.

**User** picks the recommendation and adds Refunded. Label: agree plus
info. Recorded: five transitions.

**Agent**, next round: keep polling as the fallback or replace it.
Recommended: keep it, SignalR degrades WebSocket to SSE to long-polling on
its own. And so on, one branch at a time, until the plan is solid.

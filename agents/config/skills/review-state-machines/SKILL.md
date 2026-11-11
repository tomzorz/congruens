---
name: review-state-machines
description: |
  Find every implicit state machine in a codebase or a named part of it: lifecycles spread across boolean flags, status fields, nullable "not yet" fields, call-order rules and scattered guards, with no single state value and no single place that defines the legal moves. Read-only. Reconstructs each machine with file-and-line evidence, finds reachable illegal combinations and unhandled events, ranks the machines, and shows a report with diagrams. Use when the user asks to "find all of the implicit state machines in my app", audit lifecycle or status handling, or work out why a flag combination keeps causing bugs. Pairs with formalize-state-machines, which makes one machine explicit; review-invariants and enforce-invariants are the sibling pair.
author: congruens
version: 1.0.0
date: 2026-11-09
---

# Review state machines

An implicit state machine is behaviour that depends on where something is in its life, written without saying so. Its states hide in a cluster of booleans, a status string that four functions write, a field that stays null until the request comes back. Its transitions hide in whichever handler happens to flip the flags. Nobody can list the states, so nobody can list the illegal ones, and that is where the bugs live: the spinner that never stops, the double submit, the response that lands after the user navigated away.

This skill finds those machines and reports them. It changes nothing. Making one explicit is `formalize-state-machines`, one machine per run.

## When to use

- The user asks to find the implicit state machines in an app, a module or a feature.
- A bug report involves a flag combination, a stuck status, a race between a response and a user action, or "this should never happen".
- Before a refactor of something with a lifecycle (a form, a connection, an upload, an order, a sync job), to see its real shape first.

Code that already has one state value and one transition function that every write goes through is explicit. List it in the report as such and move on, unless something writes the state around the function: a bypass makes the machine implicit again.

## Scope

Take the scope the user names: a path, a feature, a component. With no scope, take the whole repository. Read the repository's own `AGENTS.md` and README first for its architecture, so you know where lifecycles are likely to live.

For a large scope, where the tool has subagents, fan out read-only ones, one per top-level module, each given the signal list below and asked to return candidates with file and line. Subagents locate; they do not judge. You read and trace every candidate they return before it goes in the report.

## Signals

One signal is a lead, not a finding.

- Two or more booleans on the same owner that describe a phase: `isLoading`, `hasLoaded`, `isError`, `isSubmitting`, `isDirty`. Three booleans allow eight combinations; a real lifecycle rarely has more than four.
- A `status`, `state`, `mode`, `phase` or `stage` field (string, number or enum) written from more than one place, with no function that owns the writes.
- Nullable fields whose emptiness means "not yet": `session`, `startedAt`, `result`, `error`, `connection`. The phase is encoded in which of them are set.
- Call-order rules: `init` before use, `open` and `close`, `start`, `stop` and `dispose`, re-entrancy guards such as `if (this.running) return`, comments saying something "must be called first".
- The same compound guard repeated in several places: `if (user && !user.verified && !pendingInvite)`.
- Counters and clocks that change behaviour: retry counts, backoff, `lastAttemptAt`, timers that flip a flag when they fire.
- UI that branches on combinations of flags, effect chains where one effect sets state that triggers the next, step indexes in wizards, modal stacks.
- Async flows with cancellation flags, abort controllers, request sequence numbers, or "ignore this response if it is stale" checks.
- Rows with a lifecycle in storage: a `status` column, `deleted_at`, `published_at`, `approved_by`, moved by different endpoints, jobs or message handlers.
- Protocol and connection code: handshakes, reconnect loops, parsers that track where they are.
- Comments: "should never happen", "can't be X here", "only after", "by the time we get here".

Leave out a single flag set and cleared in one place. A candidate makes the report when it has at least three states, or at least two places that write its encoding, or one reachable illegal combination.

## Tracing a candidate

Reconstruct each machine from the code, not from names.

1. Name the owner: the object, component, module or row whose life this is, with file and line.
2. Find the encoding: every field, flag and value that together say which state the owner is in. Search for every write to each of them. A write you missed is a transition you will get wrong.
3. Name the states by what they mean (`Idle`, `Submitting`, `Failed`) and map each one to its encoding.
4. List the transitions: from, event, guard, to, and the file and line of the code that performs it. The event is what happened (a click, a response, a timer, a message), not the name of the function that handled it.
5. List the combinations of the encoding that mean no state at all. When there are many, group them by pattern (`isLoading` set together with `error`). For each, decide whether some sequence of events reaches it, and write that sequence down as the evidence. Mark a combination reachable only when you have a sequence; otherwise mark it "not reached by reading" or "unknown".
6. List the events each state does not handle: a cancel during submit, a response after unmount, a second click, a timeout after success. Note what the code does today in each case, if anything.
7. Merge candidates that turn out to be one machine in two places, such as UI flags that mirror a status column. Two encodings of one machine that can disagree are a finding on their own.

Everything in the report cites a file and line. A transition you inferred and did not trace is drawn and labelled as inferred.

## Ranking

Rank by what formalizing would buy. Reachable illegal combinations come first, then unhandled events with visible consequences, then the number of places that write the encoding, then bug history (`git log` on those lines, looking for fixes, is cheap evidence). A machine with one writer and no reachable illegal state goes last, whatever its size.

Give each machine a verdict:

- Formalize: it has a reachable illegal combination, or unhandled events with visible consequences and more than one writer.
- Watch: nothing is wrong today, but the encoding has several writers or is still growing. Name the change that would tip it (one more flag, a second caller, a retry).
- Leave: one writer, and no illegal combination within reach. An unhandled event in such a machine is a bug to fix where it is, without a refactor.

## The report

Build the report with the `visual-explainer` skill, show it the way the profile says to show pages, and give a short summary in chat. The report is shown, not kept. Code is the truth and a stored report goes stale with the next commit, so `formalize-state-machines` re-reads the code instead of reading the report.

The report holds:

- A summary table: machine, owner, states, writers, reachable illegal combinations, unhandled events, verdict.
- Per machine: a Mermaid `stateDiagram-v2` of the machine as the code runs it today, with each reachable illegal combination drawn as a state of its own and marked as illegal, the encoding table (each state and the field values that represent it), the transitions with file and line, the illegal combinations with their event sequences, the unhandled events, and the verdict with one line of reason.
- The explicit machines found, in one short list, with any bypass.

## After the report

Ask through the Question Tool what happens next, per machine or for the ranked list as a whole:

- Formalize now: run `formalize-state-machines` on it, one machine at a time.
- Park: record it as parked work through the `record` skill, one entry per machine, with its owner's location and the one-line reason.
- Leave: nothing is written.

An illegal combination that is reachable today is a bug, whatever the user decides about formalizing. Say so plainly in the report and in chat.

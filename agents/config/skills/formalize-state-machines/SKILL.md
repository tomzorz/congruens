---
name: formalize-state-machines
description: |
  Turn one implicit state machine into an explicit one: write down its
  states, events and transition table, settle with the user every place
  where the code's behaviour is ambiguous or wrong, pin today's behaviour
  with characterization tests, refactor to a closed set of states and a
  pure transition function, check the result with model-based tests that
  use the table as the oracle, and then propose splitting it into nested
  or parallel sub-machines where that makes it easier to reason about.
  Use when the user wants to formalize, make explicit, refactor or
  untangle a lifecycle, status handling or a cluster of flags, or picks a
  machine from a review-state-machines report. One machine per run.
author: congruens
version: 1.0.0
date: 2026-11-09
---

# Formalize state machines

`review-state-machines` finds the machines; this skill takes one of them and makes it explicit. When it is done, the machine has one state value, one closed list of events, one transition table, and one place every change goes through. The old flags are gone, and tests fail when the code and the table disagree.

One machine per run. If the user names none, run `review-state-machines` first, or ask which one. Steps 1 and 2 happen on paper and end with the user's yes; code changes start at step 3. Step 6 has a stop of its own.

Formal verification (TLA+, Quint, P, Alloy and the like) is out of scope. A later verification step would consume the transition table, which is one more reason to hold the table as data.

## 1. Reconstruct

The review report is not kept, so start from the code. Find the owner, the encoding, every write to it and every read of it, the way the "Tracing a candidate" section of `review-state-machines` does. Then write the machine down:

- States, each named by meaning, with the data that is valid only in that state (`Failed` carries the error, `Loaded` carries the result).
- Events, each named for what happened, with its payload.
- The transition table: for each state and event, the guard, the next state, and the side effects (a request sent, a timer started, a message published).
- The initial state and any final states.

Draw it as a Mermaid `stateDiagram-v2`.

When the state is stored (a status column, flags in a document), also count the records in each combination of the encoding, in data the user points you at. Never query production without the user's yes. Records already sitting in an illegal combination are cells for step 2 like any other: each needs a state to become.

## 2. Settle the behaviour

Reconstruction always turns up cells in the table where today's code is ambiguous, inconsistent or wrong: an illegal combination it can reach, an event it handles in one place and ignores in another, a response that lands after a cancel. For each such cell the explicit machine has to choose: ignore the event, reject it loudly, or move to a named state. Where the code is merely silent and one answer is plainly what it meant, take that answer and list it. Where the choice changes visible behaviour, it is the user's.

Lint the table before showing it. These checks are cheap and catch real mistakes:

- Unreachable states: no path from the initial state.
- Dead ends: a non-final state with no way out.
- Non-determinism: two transitions from the same state on the same event whose guards can both be true.
- Stuck work: a state that should be able to finish but cannot reach a final state (a failed upload that can never be retried or abandoned).

Show the diagram, the table, the lint results and the list of behaviour changes, built with the `visual-explainer` skill, and stop for the user's yes. Nothing gets refactored before that.

## 3. Pin today's behaviour

Before touching the code, write characterization tests through the owner's public surface. Drive it through the event sequences that matter and assert what it does today, quirks included. Run them; they pass on the current code. Mark the tests that cover a behaviour step 2 decided to change. Those flip on purpose in the refactor, and only those.

Tests get their dependencies the way the `coding` skill says (no mocks). The orderings that matter most, such as a response that lands after a cancel, need a dependency whose answer the test can hold back and release.

## 4. Make it explicit

Invoke the `coding` skill and the language skill before this step.

The default shape is hand-rolled:

- A closed set of states: an enum, or a tagged union whose variants carry the data valid only in that state, so the illegal combinations cannot be represented at all.
- A closed set of events, typed the same way.
- One pure transition function, `(state, event) -> state`, plus the effects to run. Hold the table as data where the language makes that practical, and have the function read it. Where guards and per-state data make a data table clumsy, an exhaustive match over state and event is the table, and a language that checks exhaustiveness then flags every cell left undecided. Effects come back as values, or run in the owner after the transition, never inside the pure function.
- One owner that holds the state and takes events one at a time. An event raised while another is being handled (an effect that answers synchronously, a callback inside a callback) is queued and handled next, never in the middle of a transition.
- Every former write to the encoding becomes an event sent to the owner. Then delete the old flags, fields and guards, and leave nothing in their place.

When the state is stored, a transition is a read, a decision and a write, and two instances can race through it. Make the write conditional on the state that was read (`UPDATE ... WHERE status = 'pending'`, or a version column), so the slower writer fails instead of overwriting. Replacing the stored encoding is a migration, and a migration that touches production data is the user's call.

A statechart library (XState, Stateless, python-statemachine and their kind) comes in only when the project already uses one, or when a split agreed in step 6 makes the hand-rolled version harder to read than the library would be. A new dependency goes through the `coding` skill's dependency ladder and needs the user's sign-off.

Run the characterization tests. Everything passes except the tests marked in step 3, which fail in exactly the way step 2 agreed. Update those to the new behaviour.

## 5. Model-based tests

The transition function needs no test against the table, because one is read from the other. What can still be wrong is everything around it: the owner sends the wrong event, skips an effect, or shows something that disagrees with its state. So the model-based test drives the real owner and uses the table as the oracle (or the transition function, where the table is not held as data):

- Generate random sequences of events from the table's event list, including the awkward ones: repeats, cancels, late responses.
- Include the events the environment sends (a response, a timeout, a message). Where their order matters, the test decides when each one lands, so the dependency behind the effect is one the test can hold back and release. The `coding` skill's test ladder says what that dependency may be.
- Send each event to the real owner, track the state the table predicts, and after every step check what the owner shows from outside against that state: the button is disabled while `Submitting`, the error is visible in `Failed`, nothing is sent from `Idle`.
- An event the table rejects fails the way the table says. Nothing else throws, and the owner never shows a state the table cannot reach.

Use the language's property-testing library with stateful or model-based support (fast-check, Hypothesis and FsCheck each have one). Read its current docs before writing the test. If the project does not have one yet, it is a new dependency and needs sign-off. Without one, write a small seeded random walk over the table by hand; it is less thorough but still worth having.

With the table as data, the lint from step 2 becomes a test too: every state reachable, no dead end. It catches the later edit that orphans a state.

## 6. Propose a split

A flat table with many states is hard to keep in your head. Once the flat machine is explicit and its tests pass, look at the table for structure that would shrink it:

- One event handled the same way from many states (cancel, logout, error, timeout): those states belong inside a parent state with one transition.
- State names that multiply two concerns (`EditingOnline`, `EditingOffline`, `ViewingOnline`, `ViewingOffline`): two independent machines, run as parallel regions.
- A group of states entered only from one place and always leaving to the same place: a sub-machine nested inside one parent state (`Editing` holding `Clean`, `Dirty` and `Validating`).
- A return to whichever sub-state was active before an interruption: a history state.
- A child with a life of its own that the parent only talks to (an upload inside a form): a separate machine that exchanges events with the parent, not a nested one.

Draw the proposal next to the flat machine (Mermaid composite states, with `--` between parallel regions; Mermaid has no history marker, so label the returning transition), say what each split buys, and stop for the user's yes. A small machine needs no split; say so in one line.

A split the user takes is a second refactor in the same hand-rolled style. Nesting is a parent state variant that holds the child's state, with the parent's transition function delegating to the child's. Parallel regions are two machines side by side. A history state is the interrupted sub-state, carried as data by the state that interrupts it.

A split reorganises the table and leaves the behaviour alone, so the tests from steps 3 and 5 pass unchanged. Where the model-based test reads its table from the code, the split rewrites the oracle along with the machine: flatten the split table and compare it with the flat one before the flat one is deleted. Where a split would change behaviour (a parent's `cancel` now reaching a state that used to ignore it), that change is the user's call, like the ones in step 2.

## Finish

The diagram is derived from the table and shown, not kept: a hand-kept diagram drifts the first time someone edits the table. If the user wants one kept anyway, it goes through the `record` skill as a diagram that names the table it was drawn from.

Commits go through the `git-workflow` and `commit-message` skills, one machine per commit, with a split as a commit of its own. A split the user did not take goes to parked work through the `record` skill.

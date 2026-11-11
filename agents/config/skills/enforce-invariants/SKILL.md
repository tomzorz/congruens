---
name: enforce-invariants
description: |
  Enforce invariants a codebase relies on but does not guarantee, picking the strongest mechanism that fits from a ladder: make the bad value unrepresentable in the type system, parse it at the boundary, constrain it in storage, route every write through one owner, assert it where it is written. Checks existing data before adding a constraint, proves the gap with a test before closing it, and removes the defensive checks the enforcement makes redundant. Use when the user wants to enforce, guarantee, validate or harden an assumption, make an illegal value unrepresentable, or act on findings from a review-invariants report.
author: congruens
version: 1.0.0
date: 2026-11-09
---

# Enforce invariants

`review-invariants` finds the assumptions nothing guarantees; this skill makes them hold. Enforced means a violation either cannot be written at all or fails loudly where it is written, not three modules later where something reads the bad value.

Take one invariant at a time, or a small batch the user picked from a report. If the user names none, run `review-invariants` first, or ask.

## 1. Restate and trace

The report is not kept, so start from the code. Restate the invariant as one falsifiable sentence. Find every place that writes the data involved (every path that creates or changes it, including jobs, migrations, imports and message handlers) and every place that relies on it. The writers are where enforcement goes. The readers tell you what breaks, and which of their defensive checks become redundant.

A single implication between two fields (`paid` means `paid_at` is set) stays here. If the invariant is one of several about which combinations of the same fields are legal, those fields encode a state machine, and one tagged union replaces all of the checks. Hand that to `formalize-state-machines` instead.

## 2. Pick the rung

Climb the ladder from the top and stop at the first rung that covers every writer found in step 1. Prevention beats detection, and detection at the write beats detection at the read. A rung covers only the writers that pass through it: a type covers the code compiled against it and nothing else that writes the same table. When the writers live in different places, combine rungs, most often a type in the code with a constraint in storage.

1. Types. Make the invalid value unrepresentable: non-nullable types, tagged unions, a newtype or branded type for an identifier or a unit, a non-empty list type. The compiler then checks every write.
2. Parse at the boundary. One constructor or factory is the only way to get the value; it validates once and returns the stronger type, so everything past the boundary can trust it. External input is parsed against a schema at the trust boundary.
3. Storage. `NOT NULL`, `UNIQUE`, `CHECK`, foreign keys, exclusion constraints. This is the only rung that holds against other writers, manual edits and races between instances. It needs a migration (step 3).
4. One owner. Make the fields private and route every write through one method that upholds the invariant: one concept in one place, as the `coding` skill puts it.
5. Assertion at the write. Fail loudly where the bad value is created, with an error that names the value and the rule. An assertion where the value is read is the weakest form of this rung.
6. Accepted and documented. When the user accepts the risk, an `invariant:` comment at the place that relies on it states the assumption and why it is not enforced, like the `coding` skill's `ceiling:` comment. That makes the invariant explicit, not enforced; say which it is.

A test comes with every rung but the last (step 4). On its own a test is not enforcement: it covers only the paths it runs.

Concurrency and multi-instance invariants are enforced by the store (a unique constraint, an optimistic concurrency token, a transaction at the right isolation level, an idempotency key), not by an in-process lock, which holds for one process only.

## 3. Check before you change

- Existing data: before proposing a storage constraint or a stricter parse of stored values, count the rows or records that already violate it, in data the user points you at. Never query production without the user's yes. Existing violations need a decision: fix them in the migration, quarantine them, or relax the rule.
- Behaviour change: list what used to pass silently and will now fail, and where it fails. A caller that relied on the silent pass breaks.
- Migration: a schema change that touches production data is the user's call.

Show the chosen rung per invariant, why the stronger rungs do not fit, the existing violations and the behaviour changes, then stop for the user's yes. For a batch, one stop covers the batch.

## 4. Prove the gap, then close it

Invoke the `coding` skill and the language skill before writing code.

1. Write a test that attempts the violation through the public surface and asserts that the write is rejected. Run it. It fails on today's code, because the write goes through, and that failure is the gap, demonstrated. If it passes, something already enforces the invariant: find out what before changing anything, and tell the user the finding was wrong.
2. Enforce at the chosen rung.
3. The test passes: the violation is rejected at the write, with an error that names the value and the rule. For a type-level rung, where the violating call no longer compiles, keep the test at the boundary where untyped input becomes the typed value.
4. For invariants over sequences of operations (ordering, consistency between records, idempotency), add a property-based test that runs random sequences of operations and checks the invariant after each one. A new testing library is a dependency and needs sign-off.

Test a race deterministically, with no threads and no timing. Replay the slower writer's write with what it would have read (a stale version, a key that now exists) and assert that the store rejects it.

Follow the `coding` skill for test dependencies: no mocks, and a real database for a storage constraint.

## 5. Clean up

Delete the defensive checks the enforcement made redundant: null checks, `?.` chains, fallbacks and re-validations at the readers, now that the value cannot be bad. That holds only once the rung covers every writer and the existing data is clean; until then the readers keep their checks. Keep the checks at trust boundaries, since those are the enforcement. Leave nothing behind where the old checks were.

## Finish

Commits go through the `git-workflow` and `commit-message` skills, one invariant or one coherent batch per commit. An invariant the user picked that did not get enforced this run goes to parked work through the `record` skill.

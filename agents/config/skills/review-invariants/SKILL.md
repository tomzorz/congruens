---
name: review-invariants
description: |
  Find every invariant a codebase relies on but does not enforce: the value assumed non-null, the email assumed unique, the total assumed to equal the sum of its lines, the init that must run first, the single instance, the payload shape nobody validates. Read-only. Each finding cites where the code relies on it, what breaks if it is false, how it could become false, and the strongest enforcement that would fit, ranked by consequence. Use when the user asks to "find every invariant my app relies on but doesn't explicitly enforce", audit hidden assumptions, or hunt for "can't happen" bugs. Pairs with enforce-invariants, which acts on the findings; review-state-machines and formalize-state-machines are the sibling pair.
author: congruens
version: 1.0.0
date: 2026-11-09
---

# Review invariants

An invariant is a condition the code assumes always holds. It is unenforced when something reads it on faith and nothing guarantees it: no type, no constructor, no constraint, no assertion at the point where it could break. These assumptions are usually true, which is why nobody wrote them down, and they are where "that can't happen" bugs come from.

This skill finds them and reports them. It changes nothing. Enforcing one is `enforce-invariants`.

## When to use

- The user asks for the invariants an app, module or feature relies on without enforcing.
- A bug turned out to be an assumption that stopped holding, and the user wants to know what else is like it.
- Before a change that breaks assumptions wholesale: going multi-instance, opening an internal endpoint to new callers, a schema migration, a new client of an API.

## Scope

Take the scope the user names, or else the whole repository. Read the repository's `AGENTS.md` and README first. For a large scope, where the tool has subagents, fan out read-only ones, one per top-level module, with the kinds below, and trace every candidate yourself before it goes in the report.

## What to look for

Start from reads that would misbehave if an assumption were false, then work back to whatever is supposed to make it true. Where there is a schema, compare it with the code: every column the code treats as required, unique or pointing at another row, against what the schema declares.

- Presence: non-null assertions (`!`, `!.`, `default!`), `.First()`, `[0]`, `unwrap()`, unchecked map lookups, casts.
- Shape and range: positive amounts, enum values stored as strings, percentages, lengths, formats (email, ISO dates), units (milliseconds or seconds, cents or whole units), time zones assumed to be UTC.
- Uniqueness: `.Single()`, a lookup by email or slug, a map keyed by something that no index or constraint keeps unique.
- Consistency between fields or records: a stored total equal to the sum of its lines, a cached copy equal to its source, a foreign key with no constraint, soft-deleted rows filtered out everywhere except one query.
- Order and time: init before use, called at most once, event A before event B, timestamps that only grow, a list that later code binary-searches because it is "always sorted", a log that is only ever appended to.
- Concurrency: one writer at a time, check-then-act without a lock or a transaction, message handlers assumed to run once when delivery is at least once.
- Deployment: a single instance (in-memory locks, caches, schedulers), clocks in sync, environment variables present, a directory that exists, a combination of feature flags that nobody ever turns on.
- External contracts: response shapes used without validation at the trust boundary, webhooks assumed to arrive once and in order, third-party identifiers assumed to stay stable.
- Authorization: an endpoint that trusts its caller because only the admin page calls it, input assumed to be sanitized upstream.
- Size: an O(n²) loop that is fine because n stays small, a payload read whole because it is small, with nothing that keeps either small.
- Comments: "assumes", "always", "never", "must", "guaranteed", "can't happen", "by the time we get here".

Leave out assumptions that never cross a boundary (a variable assigned two lines above its use) and anything the language, framework or database already guarantees. The ones worth reporting cross a function, a module, a process, a trust boundary or a stretch of time.

One implication between two fields (`paid` means `paid_at` is set) is an invariant and belongs here. Several findings about which combinations of the same owner's flags or fields are legal are one implicit state machine seen in pieces. Report them as one finding and point at `review-state-machines`; guarding the combinations one by one makes the machine harder to see.

## Each finding

- Statement: one falsifiable sentence. "Every order with status `paid` has `paid_at` set", not "orders are consistent".
- Relied on at: the file and line of each read that misbehaves if the statement is false.
- Consequence: what happens then. A crash, silently wrong data, a security hole, money moving wrongly. Silent is worse than loud.
- How it could break: the writers, inputs, races, migrations or manual edits that can make it false, each with file and line. If you found none, write "held by convention", which still counts as unenforced.
- Current protection: none, or partial (checked on one entry path and not another, covered only by a test, stated only in a comment).
- Recommended enforcement: the highest rung of the ladder in `enforce-invariants` that fits, with one line on why. A recommendation, not a change.

Every claim cites a file and line, or says that none was found.

## Ranking

Rank by consequence first, then by how plausible a violation is. A path you found outranks a race you can imagine, and silent corruption outranks a crash.

Give each finding a verdict:

- Enforce: a path to violation exists, or the consequence is silent and bad enough that convention is too thin a guard.
- Watch: no path today, but a change you can name would open one (a second writer, a second instance, a new client). Name it.
- Accept: enforcing would cost more than a violation would.

## The report

Build the report with the `visual-explainer` skill, show it the way the profile says to show pages, and give a short summary in chat. The report is shown, not kept; `enforce-invariants` re-reads the code.

It holds a ranked table (statement, consequence, current protection, recommended enforcement, verdict), then one card per finding with the fields above.

## After the report

Ask through the Question Tool what happens to the findings, per finding or for the ranked list as a whole:

- Enforce now: run `enforce-invariants` on the chosen ones.
- Park: record each as parked work through the `record` skill, with its statement and where it is relied on.
- Accept: this skill writes nothing. An accepted invariant stays implicit until `enforce-invariants` documents it where it is relied on, the last rung of its ladder.

A finding with a known path to violation is a bug today, whatever the user decides. Say so plainly.

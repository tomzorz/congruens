---
name: coding
description: |
  General rules for writing or changing code in any language: the two
  tenets (iteration speed, simple but easy to change), the order of work
  for new features, the shape of good code, ruthless cleanup, testing
  philosophy, and how a new dependency gets chosen. Invoke before touching
  code. It names the per-language skills to invoke alongside it:
  coding-csharp, coding-python, coding-typescript, coding-web.
author: congruens
version: 1.2.0
date: 2026-09-16
---

# Coding

The shared agent profile says how to work; this skill says how to write code. It applies to every language. When the code you are about to touch is C#, Python, TypeScript, or HTML and CSS, also invoke the matching skill: `coding-csharp`, `coding-python`, `coding-typescript`, `coding-web`. They carry the language's idioms and its ship checklist; nothing here repeats them.

## Tenets

Two things everything below serves.

### Iteration speed

The loop between changing something and seeing the result is what gets protected. A slow build, a test that needs a deploy, an error that says nothing: each one taxes every iteration after it.

- The inner loop comes first. Build, run one test, see the change: get that loop working and fast before the feature, not after. A new project and a feature that needs new tooling follow the same rule.
- Every test runs locally and on its own. A change that needs a deploy to verify is a defect in the setup; fix the setup.
- An error names the thing that failed: the id, the path, the value, the boundary it crossed. "Operation failed" is a bug. A log line at a boundary follows the same rule.
- Prefer tooling and layouts that reload on change over ones that need a full rebuild or restart. Cold-start cost is paid on every iteration.

In a greenfield project all four are cheap, so do them. In a large existing codebase some are a major lift: a test suite wired to a deploy, a build that takes minutes. There, treat them as the direction rather than the bar. Never make the loop slower than you found it, take the cheap wins when a change passes nearby, and do not halt a feature to rebuild the tooling unless the user asks for that.

### Simple, and easy to change

The simplest thing that works, built so the next change is cheap. The two usually agree; when they pull apart, these rules settle it.

- One concept lives in one place, so a change touches one file. Locality is most of what "easy to change" means.
- A seam (an interface with one implementation behind it) is allowed only where you can name the second implementation today: a different store, a different provider, a fake that passes the contract suite (see Testing). If you cannot name it, the seam is speculation; keep the concrete class.
- No factory for one product, no config for a value that never changes, no scaffolding for later. Later can scaffold for itself.
- A deliberate simplification with a known ceiling (a global lock, an O(n²) scan, a naive heuristic) gets a `ceiling:` comment naming the limit and the upgrade path: `// ceiling: global lock, per-account locks if throughput matters`. That comment is the cheap alternative to building the flexibility now.
- Never simplify away validation at a trust boundary, error handling that prevents data loss, security measures, accessibility basics, or anything the user asked for. When the user insists on the full version, build it without re-arguing.

## Order of work

When taking on new work:

1. Think about the architecture.
2. Research official docs, blogs, or papers on the best architecture.
3. Review the existing codebase.
4. Compare the research with the codebase to choose the best fit.
5. Implement, or ask about the trade-offs the user is willing to make.

## The shape of the code

- Write idiomatic, simple, maintainable code. Ask, every time, whether this is the simplest intuitive solution to the problem.
- Reuse before writing. Before adding a helper, a type, or a pattern, look for the one that already lives in the codebase. Re-implementing what sits a few files over is the most common slop.
- Before changing a function, read its callers. A bug report names one path; the fix goes where all the paths route through. One guard in the shared function beats a guard in the reported caller, and leaves no sibling caller still broken.
- Leave the repo better than you found it. A code smell you noticed is a code smell you fix for the next person.
- Clean up unused code ruthlessly. A parameter a function no longer needs, a helper nobody calls: delete it and update the callers. Junk does not get to linger.
- No breadcrumbs. When you delete or move code, leave nothing in the old place. No "moved to X", no "relocated". Just remove it.
- If code is very confusing or hard to understand, first try to simplify it. If it is still hard, add an ASCII diagram in a code comment.

## Testing

- No mocks. A mock is a test double that hands back scripted answers or records calls for the test to assert on: a mocking framework, a stub with canned return values, a spy. Mocks are lies: they invent behaviours that never happen in production and hide the real bugs that do.
- Every dependency a test needs comes from this ladder; stop at the first rung that works.
  1. The real thing, when it runs on the developer's machine: in-process (SQLite, a value object, a collection) or in a container (Postgres, Redis, a broker).
  2. The vendor's own emulator or sandbox (Stripe test mode, Azurite, LocalStack, the Firebase emulator). The owner of the real implementation wrote it, which beats anything written from memory.
  3. A fake: a complete, stateful implementation of the seam's interface that any caller could use unchanged, cheap enough to run in every test. A fake is a real implementation, not a mock, but only while the same contract suite runs against both the fake and the real dependency. Without that suite a fake is a mock with more lines.
- The contract suite is one set of tests with two implementations behind it. The fake run is the inner loop. The real run is what keeps the fake honest: it runs on a schedule (CI nightly, a timer), not only when someone remembers, and it is the one exception to "every test runs locally", because it verifies the fake rather than the feature.
- An agent may write the fake. Derive it from the vendor's spec when one exists rather than from recall; specs lie too, so recorded real responses, where they exist, outrank the spec as the source of the suite's fixtures.
- Test with rigour. The intent is that a new contributor cannot break things without a test saying so, and nothing slips by.
- Unless the user asks otherwise, run only the tests you added or modified, not the whole suite.

## Dependencies

Before proposing one, climb the ladder. Does the standard library do it? Does the platform (the browser, the OS, the database) do it natively? Does a dependency already in the project do it? A new package only enters when all three come up empty, and never for what a few lines cover.

Adding a dependency needs the user's sign-off; the profile says so. Before asking, do the search: find the best-maintained option that most other people use and that exposes the cleanest API. An unmaintained package that nobody else relies on is a liability, not a shortcut. Present the pick and the reason, then wait.

---
name: coding
description: |
  General rules for writing or changing code in any language: the order of
  work for new features, the shape of good code, ruthless cleanup, testing
  philosophy, and how a new dependency gets chosen. Invoke before touching
  code. It names the per-language skills to invoke alongside it:
  coding-csharp, coding-python, coding-typescript, coding-web.
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Coding

The shared agent profile says how to work; this skill says how to write
code. It applies to every language. When the code you are about to touch is
C#, Python, TypeScript, or HTML and CSS, also invoke the matching skill:
`coding-csharp`, `coding-python`, `coding-typescript`, `coding-web`. They
carry the language's idioms and its ship checklist; nothing here repeats
them.

## Order of work

When taking on new work:

1. Think about the architecture.
2. Research official docs, blogs, or papers on the best architecture.
3. Review the existing codebase.
4. Compare the research with the codebase to choose the best fit.
5. Implement, or ask about the trade-offs the user is willing to make.

## The shape of the code

- Write idiomatic, simple, maintainable code. Ask, every time, whether this
  is the simplest intuitive solution to the problem.
- Leave the repo better than you found it. A code smell you noticed is a
  code smell you fix for the next person.
- Clean up unused code ruthlessly. A parameter a function no longer needs,
  a helper nobody calls: delete it and update the callers. Junk does not
  get to linger.
- No breadcrumbs. When you delete or move code, leave nothing in the old
  place. No "moved to X", no "relocated". Just remove it.
- If code is very confusing or hard to understand, first try to simplify
  it. If it is still hard, add an ASCII diagram in a code comment.

## Testing

- No mock tests. Unit or end-to-end instead. Mocks are lies: they invent
  behaviours that never happen in production and hide the real bugs that do.
- Test with rigour. The intent is that a new contributor cannot break
  things without a test saying so, and nothing slips by.
- Unless the user asks otherwise, run only the tests you added or modified,
  not the whole suite.

## Dependencies

Adding a dependency needs the user's sign-off; the profile says so. Before
asking, do the search: find the best-maintained option that most other
people use and that exposes the cleanest API. An unmaintained package that
nobody else relies on is a liability, not a shortcut. Present the pick and
the reason, then wait.

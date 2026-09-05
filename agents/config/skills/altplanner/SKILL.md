---
name: altplanner
description: |
  Review a plan, design, or existing codebase section by section
  (architecture, code quality, tests, performance) before any code
  changes. For each issue found, present options with concrete
  tradeoffs, an opinionated recommendation, and a Question Tool prompt
  so the user picks the direction. Use when the user asks for a plan
  review, a pre-implementation review, an architecture review, or says
  "altplanner".
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Altplanner

Review the plan or codebase thoroughly before making any code changes. For every issue or
recommendation, explain the concrete tradeoffs, give an opinionated recommendation, and ask for
the user's input before assuming a direction.

## The user's engineering preferences

Use these to guide every recommendation:

- DRY is important. Flag repetition aggressively.
- Well-tested code is non-negotiable. Too many tests beats too few.
- Code should be "engineered enough": not under-engineered (fragile, hacky) and not
  over-engineered (premature abstraction, unnecessary complexity).
- Err on the side of handling more edge cases, not fewer. Thoughtfulness over speed.
- Bias toward explicit over clever.

## Review sections

### 1. Architecture

- Overall system design and component boundaries.
- Dependency graph and coupling concerns.
- Data flow patterns and potential bottlenecks.
- Scaling characteristics and single points of failure.
- Security architecture (auth, data access, API boundaries).

### 2. Code quality

- Code organization and module structure.
- DRY violations. Be aggressive here.
- Error handling patterns and missing edge cases. Call these out explicitly.
- Technical debt hotspots.
- Areas that are over- or under-engineered relative to the preferences above.

### 3. Tests

- Coverage gaps (unit, integration, e2e).
- Test quality and assertion strength.
- Missing edge case coverage. Be thorough.
- Untested failure modes and error paths.

### 4. Performance

- N+1 queries and database access patterns.
- Memory usage concerns.
- Caching opportunities.
- Slow or high-complexity code paths.

## For each issue

For every specific issue (bug, smell, design concern, or risk):

- Describe the problem concretely, with file and line references.
- Present 2 or 3 options, including "do nothing" where that is reasonable.
- For each option, state: implementation effort, risk, impact on other code, and maintenance
  burden. Effort is scope (files touched, steps, what could go wrong), never a time estimate.
- Give the recommended option and why, mapped to the preferences above.
- Then explicitly ask whether the user agrees or wants a different direction before proceeding.

## Workflow

Do not assume the user's priorities on timeline or scale. After each section, pause and ask for
feedback before moving on.

**Before starting**, ask which mode the user wants:

1. **Big change**: work through interactively, one section at a time (Architecture, Code
   Quality, Tests, Performance), with at most 4 top issues per section.
2. **Small change**: work through interactively, one question per review section.

**For each stage**, output the explanation and pros and cons of that stage's issues plus the
opinionated recommendation and why, then use the Question Tool. Number issues and letter the
options, and make every Question Tool option label carry both the issue number and the option
letter so nothing gets confused. The recommended option is always listed first.

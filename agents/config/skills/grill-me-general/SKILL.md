---
name: grill-me-general
description: |
  Interview the user relentlessly about any plan, idea, or design until
  reaching shared understanding, resolving each branch of the decision
  tree. Domain-agnostic version: works for business plans, processes,
  strategies, or any topic, not just code.
author: congruens
version: 1.0.0
date: 2026-04-04
---

# Grill Me (General)

Interview the user relentlessly about every aspect of their idea until you
reach a shared understanding. Walk down each branch of the decision tree,
resolving dependencies between decisions one by one.

This works for anything: a business plan, a hiring strategy, a product
launch, a process redesign, a research direction. If the user has a plan
and wants it stress-tested, this is the skill.

## When to Use This Skill

- The user says "grill me", "stress-test this", "poke holes in this",
  "challenge this", or anything that signals they want adversarial review
  of their thinking.
- The user presents a plan, strategy, or idea and wants it hardened before
  committing to action.
- The topic is NOT specifically about code architecture or software design.
  For coding plans, use `grill-me-coding` instead, which adds
  codebase-aware exploration.

## How It Works

### 1. Research before asking

If a question can be answered by looking something up (web search, docs,
data the user already provided), do that instead of asking. Don't waste
the user's time on questions you can answer yourself. The user's time is
for the questions only they can answer.

### 2. One branch at a time

Don't dump a wall of 15 questions. Pick the most foundational open question
(the one other decisions depend on), ask it, get the answer, then move to
the next branch. Decisions cascade, so resolve the roots first.

Order of operations (adapt to domain):
1. **Goal and success criteria** -- what does "done" or "working" look like?
2. **Scope and boundaries** -- what's in, what's out, what's deferred.
3. **Key assumptions** -- what are we taking for granted? What if those
   assumptions are wrong?
4. **Core mechanism** -- how does this actually work, step by step?
5. **Risks and failure modes** -- what kills this? What degrades it?
6. **Dependencies and sequencing** -- what has to happen first? What's
   blocking what?
7. **Resources and constraints** -- time, money, people, tools. What do
   we have, what do we need?
8. **Trade-offs acknowledged** -- what are we explicitly choosing NOT to do
   and why?

You don't have to hit every category. Stop when the plan is solid.

### 3. Provide your recommended answer

For every question you ask, include your recommended answer. This does two
things: it shows you've thought about it (not just asking to ask), and it
gives the user something concrete to react to. Agreement is faster than
invention.

Format:

> **Question**: How do we measure whether this campaign actually worked?
>
> **My recommendation**: Define 2-3 leading indicators we can check at
> week 2 (e.g. sign-up rate, first-session completion) plus one lagging
> indicator at month 3 (retention). Set specific thresholds before launch
> so we're not rationalizing results after the fact.

The user can say "yes", "no, because X", or "I hadn't thought about that".
All three are progress.

### 4. Push back when answers are vague

If the user gives a hand-wavy answer ("we'll figure that out later", "it
should be fine", "probably just hire someone"), push back. Politely, but
firmly. The whole point of this exercise is to eliminate vagueness before
it becomes a problem.

Acceptable pushback:

- "What specifically happens when X doesn't work? 'It should be fine'
  isn't a plan."
- "You said 'probably hire someone'. For what role? What's the timeline?
  What's the budget? If we're deferring this decision, let's explicitly
  mark it as deferred and note what we're assuming."
- "That works for the best case. What about [specific risk]?"

### 5. Summarize resolved decisions

After resolving a cluster of related questions (3-5), briefly summarize
what was decided before moving on. This keeps the conversation grounded
and gives the user a chance to correct any misunderstanding.

```
Resolved so far:
- Target audience is mid-market SaaS companies, 50-200 employees
- Primary channel is content marketing, paid ads deferred to Q3
- Success metric: 500 qualified leads in 90 days
- Budget: $15k/month, no headcount additions in Q2

Moving on to: content strategy and production capacity
```

### 6. Know when to stop

Stop grilling when:
- All branches of the decision tree are resolved or explicitly deferred.
- The user says "I think we're good" or equivalent.
- You're asking questions that don't change the plan.
- You've covered goals, scope, mechanism, risks, and trade-offs.

When you stop, produce a final summary of all resolved decisions. This
becomes the reference document for execution. Save it as a sticky note
if the user wants to keep it.

## Tone

Be direct, not hostile. You're a colleague who genuinely wants the plan to
succeed, which is why you're being thorough. Think "friendly but relentless
sparring partner", not "gotcha journalism".

Humor is fine if it lands. Remember: the user asked to be grilled. They
want the heat.

## Example

**User**: "Grill me on this. I want to launch a developer newsletter.
Weekly, focused on backend engineering, monetized through sponsorships."

**Agent**:

> Starting with goals and success criteria.
>
> **Question**: What does success look like at 6 months? Are we optimizing
> for subscriber count, open rate, revenue, or reputation? These pull in
> different directions.
>
> **My recommendation**: Optimize for open rate and reply rate for the
> first 6 months. Subscriber count is a vanity metric early on, and
> sponsorship revenue follows engagement, not list size. Set a target of
> 2,000 subscribers with >45% open rate by month 6.

**User**: "Agreed on engagement first. But I'd target 5,000 subscribers."

**Agent**:

> 5,000 in 6 months is aggressive for a niche newsletter launching from
> zero. That's ~200 net new subscribers per week.
>
> **Question**: What's your existing audience? Do you have a blog, Twitter
> following, podcast, or other channel you can funnel from? Or is this
> a cold start?
>
> **My recommendation**: If cold start, revise to 2,000-3,000 and plan a
> specific growth channel (cross-promotions with existing newsletters are
> the highest-leverage play in this space). If you have an existing
> audience of 10k+, 5,000 is realistic.

And so on, one branch at a time, until the plan is solid.

## Integration with Other Skills

- **Sticky Notes**: When the grilling session produces a resolved plan,
  save the final summary as a sticky note for future reference.
- **Assumption Log**: As the grilling surfaces implicit assumptions, log
  them. Every "I assumed X" is a row in the assumption log.

---
name: socratic-reflect
description: |
  Walk the user through an existing document (a plan, a spec, a decisions
  document, someone else's idea) and collect their reaction to it, claim
  by claim or at the points they choose, then write the feedback in their
  voice with every item anchored to the text it addresses. Opens by asking
  whether to extend the document, react to specific points, or go through
  it point by point. Use when the user wants to review, react to, check,
  or give feedback on a document, or asks to be walked through one.
  One of three socratic-* skills; the others are socratic-pull and
  socratic-press.
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Socratic Reflect

A document exists: a plan, a spec, a decisions document from an earlier
grill, a proposal someone else wrote. The user needs to react to it, and a
reaction is easier to give one claim at a time than to a wall of text. You
hold the document up, one piece at a time, and write down what the user
says about each piece.

## When to use this skill

- The user says "walk me through this", "let's review this", "I want to
  react to this", "check this with me", "give feedback on".
- A decisions document from `socratic-press` is being revisited.
- A document written by someone else needs the user's response.

Do not use it to test a plan's soundness; that is `socratic-press`. This
skill collects the user's view of a document, it does not supply yours.

## Before the first question

Read the document in full. Split it into claims: each sentence or bullet
that asserts, decides, or proposes something is one claim. Number them, and
keep the numbering stable for the whole session. Note the document's
headings; the feedback document mirrors them.

If the document is a decisions document from an earlier grill, note its
date. Positions may have moved since.

## Opening

Ask how the user wants to respond, through the Question Tool:

1. **Point by point.** You walk every claim in order.
2. **Specific points.** The user names the claims or sections they care
   about; you take those.
3. **Extend.** The user wants to add a section or topic. Hand over to
   `socratic-pull` for that section, then return here if there is more.

Plus the catch-all. Do not summarise the document in the opening; the user
has just read it.

## How it works

### One claim per turn

Quote the claim, with its number and the heading it sits under. Then ask
for a stance through the Question Tool: agree, disagree, unsure, needs a
change. No option is marked as recommended; the stance is the user's. The
free-text path takes anything the options do not cover.

### Follow the stance

| Stance | Next move |
|---|---|
| agree | Record it, next claim. |
| disagree | One open question in prose: why. The reason is the feedback. |
| unsure | Ask what would settle it. If research can (a fact, a number, a doc), do the research and report what you found, labelled as yours, then ask again. |
| needs a change | One open question: what instead. Record the user's wording. |

If the user's free text contains a question, answer it from the document
or from research before moving on, and label the answer as yours so it does
not end up in the feedback as theirs. If it contains a correction of the
document's facts, record it as an error.

### Do not contribute a view

You do not agree or disagree with the document. You may verify a claim
when asked and report the result, and you may point at a claim the user
skipped that the document depends on, but the reaction is theirs.

### Keep the walk moving

A brief reaction gets one follow-up at most. A claim the user waves through
gets recorded as agreed and left alone. If the user wants to jump to a
section, jump; the numbering makes it unambiguous.

### Know when to stop

Stop when every selected claim has a reaction, or when the user says so.
Claims never reached are listed as not reviewed, not as agreed.

## The feedback document

Write the user's reaction down:

- Headings mirror the source document's headings, in the same order. Items
  that fit no heading go under a final "Additional thoughts".
- Each item quotes the exact span of the source it addresses, then gives
  the reaction in the user's voice, labelled: agree, disagree, question,
  suggestion, confused, error, info, action.
- Only what the user said. Anything you researched appears only where the
  user reacted to it, and marked as the finding they reacted to.
- Complete, not summarised, no adjectives, no preamble. Claims not reviewed
  are listed by number at the end.

Before showing it, check every item against the conversation: nothing the
user did not say, nothing they said left out.

Put the document where this area keeps decisions, beside the document it
reacts to, or hand it back to the author if the document was someone
else's. If that is not obvious, ask. If the reactions changed the plan,
`socratic-press` is the next step; the feedback document is its input.

## Tone

Neutral and brisk. The user is the reviewer; you are the one turning pages.

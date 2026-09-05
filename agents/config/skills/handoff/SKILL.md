---
name: handoff
description: |
  Compact the current conversation into a handoff another agent can pick
  up cold. Checks first that everything is settled (committed, recorded,
  nothing left running), asks the user to settle what is not, then writes
  the handoff into the chat: what the next session is for, where the work
  stands, what to read first, which skills to invoke, and the first
  command to run. Saved to a file only when asked, and deleted once
  consumed.
argument-hint: "What will the next session be used for?"
disable-model-invocation: true
author: congruens
version: 1.0.0
date: 2026-09-05
---

# Handoff

A handoff is the one document that lets a fresh agent continue this work
without this conversation. It is short, because everything durable already
lives somewhere better (code, commits, specs, issues, the area's records),
and the handoff only points at those places and says where to start.

## Settle first

Before writing anything, check what this session leaves behind that the
next one cannot see:

- Uncommitted changes, and on which branch or worktree.
- Servers, tunnels, watchers or other processes still running.
- Rulings the user gave, decisions taken, dead ends hit, open questions,
  verification done or skipped, that were not yet recorded where the area
  keeps such things.

List what you found and ask the user to have it settled before the
handover: committed or stashed, recorded, torn down. Do not write the
handoff around unsettled state; a handoff that says "there are
uncommitted changes, be careful" is a handoff that failed. If the user
says to proceed anyway, say so at the top of the handoff and list the
unsettled items there, and nowhere else.

## Write it

Into the chat, as the final message, unless the user asks for a file.
Tailor it to the argument: the user's description of what the next
session is for decides what is relevant and what is not.

Sections, in this order:

1. **Purpose.** What the next session is for, in the user's words if they
   gave them.
2. **Where the work stands.** The current state in a few sentences, with
   every reference resolvable cold: full paths, commit hashes, issue URLs,
   branch names. Never "the file we discussed" or "the earlier change".
3. **Read first.** The files the next agent opens before anything else:
   the area's `AGENTS.md` and its records file, the spec or plan the work
   follows, the last commit's message if it carries reasoning.
4. **Suggested skills.** The skills the next agent should invoke, by name,
   with one clause each on why.
5. **First command.** The concrete first step, as something that can be
   run or opened. "Continue the refactor" is not a first step.

Leave out:

- Anything already captured in an artifact. Reference it by path or URL
  instead of restating it.
- The conversation itself: how decisions were reached, what was said in
  what order. The results are recorded; the path to them is not needed.
- Sections with nothing in them. A short session gives a short handoff.

Redact secrets and personal data: API keys, tokens, passwords, account
identifiers, anything that would be a problem in a pasted message.

## If it was saved to a file

The file is transient. The agent that consumes it deletes it when the
work resumes, and a handoff superseded by a newer one is deleted by the
session that writes the newer one. Nothing durable is allowed to live only
in a handoff; if something in it turns out to matter past the next
session, record it properly and drop it from the file.

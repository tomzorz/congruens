---
name: commit-message
description: |
  Write the commit message for a git commit. Invoke this before EVERY
  `git commit`, without exception, including one-line commits, fixups,
  amends, and squash messages. Also use when rewording an existing commit,
  writing a merge or revert message by hand, or reviewing someone else's
  message. Enforces the subject/body split, the 50-character imperative
  subject, the 72-column body, and what-and-why over how.
author: congruens
version: 1.0.0
date: 2026-08-12
---

# Commit Message

A diff shows what changed. Only the message says why. Six months from now the diff is still there and the reasoning is gone, unless you wrote it down here.

This skill is the house standard for every commit message.

## When to use this skill

Every time you are about to run `git commit`. Also for `git commit --amend`, squash and fixup messages, `git rebase --interactive` rewords, hand-written merge or revert messages, and reviewing a message someone else wrote.

There is no "too small for this" commit. A one-line typo fix still gets a properly formed subject line; it just does not get a body.

This skill covers the message only, not whether the commit should happen.

## Before you write

Read `git log` for the repo first (`git log --oneline -20` plus one or two full messages). If the project already has a convention (Conventional Commits prefixes, ticket keys in the subject, a `Signed-off-by` trailer), that convention wins over anything below that contradicts it. Match the neighbours.

Then look at what you actually staged: `git diff --cached`. Write the message from the diff, not from memory of what you intended to do.

## The shape

```
Summarize changes in around 50 characters or less

More detailed explanatory text, if necessary. Wrap it to about 72
characters. In some contexts, the first line is treated as the subject
of the commit and the rest of the text as the body. The blank line
separating the summary from the body is critical (unless you omit the
body entirely); various tools like `log`, `shortlog` and `rebase` can
get confused if you run the two together.

Explain the problem that this commit is solving. Focus on why you are
making this change as opposed to how (the code explains that). Are
there side effects or other unintuitive consequences of this change?
Here's the place to explain them.

Further paragraphs come after blank lines.

 - Bullet points are okay, too

 - Typically a hyphen or asterisk is used for the bullet, preceded by a
   single space, with blank lines in between

If you use an issue tracker, put references to them at the bottom:

Resolves: #123
See also: #456, #789
```

## The seven rules

### 1. Separate subject from body with a blank line

Git splits the message at the first blank line. Everything before it is the subject and gets used on its own all over the place. No blank line means no subject, and `log`, `shortlog`, and `rebase` will run the two together and print nonsense.

Short, self-evident commits can be subject-only. If you write a body, the blank line is mandatory.

### 2. Limit the subject line to about 50 characters

50 is a target, not a hard rule. 72 is the hard ceiling: GitHub warns past 50 and truncates with an ellipsis past 72, and `git log --oneline` output stops being scannable long before that.

Anything that does not fit belongs in the body.

### 3. Capitalize the subject line

`Fix the parser`, not `fix the parser`. If the repo's existing log uses a lowercase convention (common with Conventional Commits: `fix: handle empty input`), follow the repo.

### 4. Do not end the subject line with a period

It is a title, not a sentence. You have 50 characters and the period is not earning its slot.

### 5. Use the imperative mood in the subject line

Write commands, not reports: `Fix bug`, not `Fixed bug` or `Fixes bug`.

The test: the subject must complete this sentence.

> If applied, this commit will _____.

`If applied, this commit will refactor subsystem X for readability` reads correctly. `If applied, this commit will fixed bug with Y` does not.

This is not pedantry about grammar, it is consistency with git itself. Every message git generates for you is imperative: `Merge branch 'feature'`, `Revert "Add the thing"`. A log where your commits are in past tense and git's are in the imperative reads like two people arguing.

The body is free to use whatever mood you like. Past tense there is normal and fine.

### 6. Wrap the body at 72 characters

Git does not wrap text for you. The default pager is `less -S`, which does not wrap either, so an unwrapped paragraph runs off the right edge of the terminal and you have to scroll sideways to read it.

72 comes from arithmetic: an 80-column terminal, minus the 4-space indent `git log` adds, leaves room to spare. It also survives `git format-patch --stdout` piping a commit into an email where reply markers eat further columns.

Wrap manually. Do not rely on the editor doing it, and do not paste a single 400-character paragraph and hope.

### 7. Use the body to explain what and why, not how

The code in the diff is the definitive account of how. Nobody needs it restated in prose.

What the diff cannot tell you:

- What was broken or missing before this commit.
- Why this approach and not the obvious alternative.
- What side effects or non-obvious consequences it has.
- What constraint (a bug report, a platform quirk, a deadline) forced the shape of it.

Write those. A body that says "changed the loop to a `while`" is dead weight; a body that says "the `for` loop skipped the last element when the list length was odd" is the whole point of the commit message.

## Where the subject line ends up

The 50-character rule earns its keep because the subject appears alone, without the body, in most places you will ever read git output:

- `git log --oneline` and `git log --pretty=oneline`
- `git shortlog`, which is how you generate a changelog
- `git rebase --interactive` pick lists
- Generated merge commit messages
- Reflog entries
- `git format-patch` email subjects
- `gitk`, GitHub, and every other UI on top of git

A subject that only makes sense with the body attached is broken in every one of those.

## Writing the message mechanically

Do not build a wrapped multi-paragraph body out of `-m` flags. Repeated `-m` gives you a blank line between chunks and no wrapping at all, so bodies come out as single long lines.

Subject-only commits are the exception, `-m` is right there:

```bash
git commit -m "Fix off-by-one in the pagination offset"
```

For anything with a body, write the message to a file and pass it with `-F`:

```bash
git commit -F .git/COMMIT_DRAFT.txt
```

Write the file with the editor tool, wrapped by hand at 72 columns, then delete it after the commit. Heredocs work too, but a file is easier to fix when the wrapping is wrong.

Trailers go at the bottom, after a blank line, one per line: `Resolves: #123`, `See also: #456`.

## Checklist

Run this before every `git commit`:

1. Subject and body separated by a blank line (or no body at all).
2. Subject at most 50 characters, hard limit 72.
3. Subject capitalized, matching the repo's existing convention.
4. No trailing period on the subject.
5. Subject completes "If applied, this commit will _____".
6. Body wrapped at 72 columns.
7. Body explains what was wrong and why this change, not how the code works.
8. Issue references as trailers at the bottom.

## Examples

Bad:

```
fixed the thing where users couldn't log in sometimes.
```

Lowercase, past tense, trailing period, 54 characters of vagueness, no body, and "sometimes" is doing a lot of work.

Good:

```
Fix login failure for users with expired sessions

The session middleware treated an expired token the same as a missing
one and redirected to /login, but the login handler then found the
stale cookie and short-circuited straight back, producing a redirect
loop.

Clear the cookie before redirecting so the login handler sees a clean
request. This also fixes the "too many redirects" reports from Safari,
which caches the 302 more aggressively than Chrome does.

Resolves: #481
```

Bad subject lines and their fixes:

| Bad | Why | Fix |
|-----|-----|-----|
| `Updated README` | Past tense | `Update README` |
| `Fixes crash on startup` | Third person | `Fix crash on startup` |
| `bug fix` | Says nothing | `Fix null deref in config loader` |
| `Change line 42 of parser.go to use strconv.Atoi` | Describes how | `Reject non-numeric port values` |

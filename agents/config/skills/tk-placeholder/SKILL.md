---
name: tk-placeholder
description: |
  Leave a searchable TK placeholder instead of guessing, inventing, or leaving
  a blank when a fact is missing from text you are writing. Use whenever a
  value, name, number, date, quote, link or section is unknown and has to be
  filled in later: drafts with gaps, "TBD", "fill in later", "we don't have
  that number yet", square-bracket stand-ins, X marks. Covers the TK_thing
  form, why it is one double-clickable token, and how to format it in
  markdown, Word and HTML so typing over the selection already produces the
  right formatting.
author: congruens
version: 1.0.0
date: 2026-09-12
---

# TK placeholders

When you are writing text and a fact is missing, there are three bad moves and one good one. Bad: invent a plausible number, leave a blank line, or write something vague enough to hide the hole. Good: leave a TK.

TK is magazine-desk shorthand for "to come". The letter pair is close to nonexistent in ordinary English prose, so a search for `TK` finds every unfinished spot in a document and almost nothing else. That searchability is the whole point of the convention; anything that weakens it defeats it.

## The form

**`TK_thing`** when you know what the gap is. **`TK`** alone when you don't know yet what the gap even is.

- Lowercase snake after the `TK_`: `TK_price`, `TK_release_date`, `TK_ceo_name`, `TK_benchmark_result`.
- Name the gap by what the answer is, not by where it goes. `TK_price`, not `TK_second_paragraph`.
- Put units and currency in the name when the answer is a number: `TK_price_usd`, `TK_latency_ms`, `TK_headcount`.
- The sentence stays grammatical with the placeholder in it. It reads as the noun phrase it will become:

  > The yearly subscription costs TK_price a month.
  > We shipped on TK_release_date, TK_days_late days behind the original date.

- One token, no spaces, no punctuation inside it.

## Why the underscore

Double-click selects a word. Underscore counts as part of a word in Word, Google Docs, browsers and every code editor worth using; hyphens, dots, spaces, slashes and brackets do not. `TK_price` double-clicks as one selection. `TK-price` double-clicks as `price` and leaves you a stray `TK-` to clean up by hand, which is exactly the sort of thing that survives into a published document.

The underscore is the safest separator we have, not a guaranteed one. If you are writing in an editor nobody here has used before, double-click one placeholder and check before you scatter forty of them through the file.

Punctuation that belongs to the final sentence stays **outside** the token, where it is supposed to survive the edit:

> The plan costs $TK_price a month.

Double-click grabs `TK_price`, you type `49`, the `$` stays put. That is the behaviour you want.

## Format it as the answer, not as a placeholder

The placeholder is a rehearsal of the finished text. Select it, type the real value, and the result must be publishable with no further cleanup. That means whatever formatting the answer needs, the placeholder already carries, and nothing else.

**Do not decorate it.** No `**TK_price**`, no backticks, no `[TK_price]`, no `{{TK_price}}`, no `<TK_price>`, no yellow highlighter, no red text. Word carries highlighting and character formatting into whatever you type over a selection, so a highlighted placeholder becomes a highlighted price. Brackets and braces break double-click selection and collide with markdown links, HTML tags and template syntax.

**Do carry the real formatting.** If the missing text is a heading, the placeholder goes in the heading. If it sits inside a bolded product name, write it bold. If it is a link, both halves are placeholders: `[TK_product_name](TK_docs_url)`. If the answer will be code, a code span is correct: `` `TK_flag_name` ``.

Per medium:

| Medium | Placeholder is | Not |
|---|---|---|
| Markdown | plain text in the sentence | `**TK**`, `` `TK` ``, `[TK]` |
| Word / docx | text in the same run and character style as the surrounding sentence | highlighted, coloured, a content control, a field, a comment anchor |
| HTML | a text node inside the element that will hold the answer | `<span class="tk">`, an HTML comment |
| Plain text, email, chat | as written | anything else |

Visibility is not the placeholder's job. Searching for `TK` is what finds them, and it finds them in a way that survives copy-paste, format conversion and someone else's editor.

## Never ship a TK

Before you hand text over, search it case-sensitively for `TK` and report what is left. List each placeholder with the question it stands for, so the reply can fill them:

> Three placeholders left: `TK_price` (monthly price in USD), `TK_release_date` (ship date), `TK_ceo_name` (who signs the letter).

If the text is going out as-is right now, say so out loud. A silently guessed number is worse than an obvious hole.

And TK is not a way to dodge a question. If the user can answer it in one line, ask instead of leaving a gap.

## When not to use TK

- **Code.** Code gets a value that compiles and a `TODO` comment. Prose inside a string literal can still carry a TK.
- **Machine-filled templates.** Jinja, mustache, mail merge, i18n keys: use the template syntax the tool expects. TK marks what a human has to fill; template syntax marks what a machine fills.
- **Specs.** A missing requirement is not a hole to paper over. See the Lojbanlite skill: name the open question rather than embedding a blank in a normative sentence.

## Stand-ins to replace on sight

| Seen | Use | Why |
|---|---|---|
| `[TBD]`, `[insert name]` | `TK_thing` | brackets break double-click and collide with markdown links |
| `XXX`, `FIXME` | `TK_thing` | code conventions, and `XXX` shows up in real content and redactions |
| `<placeholder>` | `TK_thing` | angle brackets disappear in HTML and break markdown |
| `$X`, `N`, `some number` | `$TK_price` | unsearchable, and reads as a real value to a skimming reader |
| `TK-release-date` | `TK_release_date` | hyphen breaks double-click selection |

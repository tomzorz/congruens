---
name: lojbanlite
description: |
  Write or rework software specifications in Lojbanlite, a controlled English
  where every normative sentence has exactly one reading. Use when writing or
  reviewing requirements, acceptance criteria, design specs, API contracts,
  procedures, runbooks, or safety instructions. Also use when the user mentions
  Lojbanlite, controlled language, simplified or controlled English, RFC 2119
  keywords, or asks to make a spec unambiguous. Enforces explicit logical
  connectives and quantifiers, RFC 2119/8174 normative keywords, named agents,
  one instruction per sentence, sentence length caps, a per-project glossary
  with one term per concept, and warnings before destructive steps.
author: congruens
version: 1.0.0
date: 2026-07-27
---

# Lojbanlite

A controlled English for software specifications. The name is honest about the ancestry: lojban is
a constructed language built so that every utterance has exactly one grammatical parse. Lojbanlite
borrows the goal, not the grammar. A Lojbanlite sentence is still English, but every normative
sentence has exactly one reading.

Three sources feed it, none of them wholesale:

- **Controlled-language practice** from the maintenance-manual tradition: sentence caps, one
  instruction per sentence, imperative procedures, noun-cluster limits, condition-first ordering.
  The rules are stated in our own words. A controlled dictionary is deliberately not adopted; a
  per-project glossary replaces it.
- **RFC 2119/8174**: the normative-strength keywords (MUST, SHOULD, MAY) that controlled languages
  lack and specs need most.
- **Mainstream tech style-guide mechanics**: sentence case, Oxford comma, verb-first sentences,
  numerals, bias-free and global-ready English, can/might discipline. The conversational voice
  those guides favor (contractions, "write like you speak") is explicitly NOT adopted. Specs are
  not friendly conversations.

Full rule set with IDs in `references/rules.md`. The ambiguity catalog, which is the part lojban
inspired, is in `references/ambiguity.md`.

## Tenets

Cite these when rules conflict. Lower number wins.

- **T1. One reading.** If a reasonable reader can parse a normative sentence two ways, the sentence
  is wrong, even if every individual rule passes.
- **T2. Clarity beats compliance.** When a rule and clarity conflict, clarity wins and the deviation
  is noted with the rule ID. Never silently obey a rule into stilted nonsense, and never silently
  break one either. This tenet exists because rule-optimizing writers (human and model alike)
  produce technically-conformant garbage.
- **T3. Named agents.** Every action has an explicit actor. "The token is validated" hides the most
  important fact in the sentence.
- **T4. One term, one concept, both directions.** The glossary is a bijection.
- **T5. Restructure, do not compress.** Length limits are met by splitting sentences, never by
  dropping articles or words like "that".

## When to apply

Apply Lojbanlite to requirements, acceptance criteria, design and interface specs, API contracts in
prose, procedures, runbooks, safety and rollback instructions, and the normative parts of an ADR.

Do not apply it to code, comments, commit messages, READMEs, tutorials, chat, quoted text, or error
output. Never run the Humanizer skill and this skill on the same text. They pull in opposite
directions by design: Humanizer makes prose sound human, Lojbanlite makes it mechanical on purpose.

## Workflow

### 1. Confirm the text is a specification

If it is narrative documentation, stop and say so. If the document mixes normative and narrative
parts, ask which parts are normative, or split them.

### 2. Find or start the glossary

Look for `GLOSSARY.md`, `docs/glossary.md`, or a glossary section in the spec. If none exists,
that is the first finding to report, ahead of any wording problem. Start one from the terms the
spec already uses. Entry format:

```markdown
### session token (noun)
The signed credential that the auth service issues at sign-in.
Do not use: auth token, token, credentials.
```

### 3. Classify each block

Procedural (tells the reader to do something), descriptive (tells the reader something), or safety.
The length caps and verb forms differ, so classify before counting anything.

### 4. Rewrite, rule by rule

Work through `references/rules.md` and `references/ambiguity.md`. Every change maps to a rule ID.
If the document is a requirements document or acceptance criteria and has no requirement IDs,
assign stable ones (REQ-XXX-n) per rule A10. Procedures, runbooks, and ADRs rely on numbered steps
and structure instead; do not decorate them with IDs.

### 5. Report

Present the reworked text, then a change table:

| Location | Rule | Was | Now |
|----------|------|-----|-----|
| REQ-4 | S2 (34 words) | ... | ... |
| REQ-7 | N2 | shall be able to be configured | can configure / MAY configure |
| REQ-9 | A1 | A or B | A or B, or both |

### 6. Check meaning survived, and surface what the original never said

Read original and rewrite side by side. Confirm no requirement was weakened, dropped, or invented.
Then list every place where the original was ambiguous and the rewrite had to pick a reading. Do
not pick silently; present the fork to the author. **This list is the highest-value output of the
skill.** The rewrite is cleanup; the fork list is the spec review.

Common forks the rules force into the open:

- "should" in the original: RFC SHOULD, or colloquial must? (N1, N5)
- Passive voice: who actually does this? (T3, S3)
- "or": inclusive or exclusive? (A1)
- "any": every, or at least one? (A3)
- Nominalization: "validation is required", by whom, of what, when? (S6)
- Missing failure path: the spec says what must happen, never what happens when it does not.

## The ten that catch almost everything

Check these first. Full definitions in the references.

1. **N1**: normative strength only via MUST / MUST NOT / SHOULD / SHOULD NOT / MAY, in caps.
2. **S1**: one instruction or one assertion per sentence.
3. **S3**: active voice, named agent, imperative for steps.
4. **S2**: 20 words per procedural sentence, 25 per descriptive. Identifiers count as one word.
5. **S5**: simple tenses only; no auxiliary stacks ("shall be able to be configured").
6. **S6**: verbs, not nominalizations ("validate", not "perform validation of").
7. **A1**: every "or" marked inclusive or exclusive; "and/or" banned.
8. **A3**: "any" and "some" banned; use "each", "at least one", "exactly one", "no".
9. **G2**: one term per concept, everywhere, forever.
10. **W1**: warnings before the step they protect.

## Worked example

Before:

> The system shall be able to be configured to utilize an alternative authentication provider; in
> order to facilitate this, the administrator should perform validation of the provider
> configuration prior to enabling it, ensuring that subsequent authentication attempts will not be
> failing.

After:

> REQ-AUTH-1: The administrator MAY configure the system to use a different authentication
> provider.
> REQ-AUTH-2: Before the administrator enables the provider, the administrator MUST validate the
> provider configuration.

Forks surfaced to the author, not silently resolved:

- "should" became MUST. If deviation is acceptable, it is SHOULD, and N5 requires the reason.
- The original never defines what "validation" checks. The glossary needs an entry or REQ-AUTH-2
  needs a reference.
- The original never states what happens when validation fails. Missing failure path.
- "ensuring that subsequent authentication attempts will not be failing" claims an outcome no
  mechanism in the text produces. Dropped as content-free; flagged in case the author meant a real
  requirement.

## References

- `references/rules.md`: the full rule set with IDs.
- `references/ambiguity.md`: the lojban-inspired ambiguity catalog with before/after pairs.
- RFC 2119 and RFC 8174 for the keyword definitions.

# Lojbanlite rules

Cite rules by ID. Sections: G (glossary and terms), N (normative strength), S (sentences),
A (ambiguity, summarized here, full catalog in `ambiguity.md`), C (procedures), D (descriptive
structure), W (warnings), M (mechanics).

The tenets T1 to T5 in SKILL.md govern conflicts. T2 is the escape hatch: clarity beats compliance,
and deviations are noted, never silent.

---

## G. Glossary and terms

**G1.** Every domain term in a spec comes from the project glossary. A term not in the glossary is
either plain English (fine) or a gap (report it). There is no other controlled dictionary.

**G2.** One term per concept. If it is the "session token" in REQ-1, it is the "session token" in
REQ-40. Synonym variation is a style habit and it is forbidden. Each glossary entry lists its
banned synonyms.

**G3.** One concept per term, in one part of speech. A glossary noun is never used as a verb, and a
glossary verb is never used as a noun. If "deploy" is your verb, write "deploy the service", not
"run the deploy".

**G4.** Prefer the short, common, boring term. No slang, no jargon, no regionalisms outside the
glossary. "Spin up", "nuke", "hydrate", and "footgun" do not appear in specs.

**G5.** Maximum three words in a noun cluster. "User session token expiry policy" has no single
parse. Either restructure with a preposition ("the expiry policy for the session token") or define
the concept once in the glossary and register a short form. Hyphenate words that act as one unit.

**G6.** US spelling. Identifiers, code, commands, file paths, flags, API routes, UI strings, and
error messages are quoted verbatim: never rewritten, never reflowed, and each counts as one word.

## N. Normative strength

**N1.** Normative force is expressed only through the RFC 2119/8174 keywords, in capitals: MUST,
MUST NOT, SHOULD, SHOULD NOT, MAY. Include the BCP 14 boilerplate once per document. Lowercase
"must" or "should" in normative text is a rule violation, because the reader cannot tell binding
from casual.

**N2.** "Shall" is banned entirely. "Will" states a future fact, never an obligation.

**N3.** Modal discipline outside the keywords: "can" means capability, "might" means possibility.
Lowercase "may" is banned (ambiguous between permission and possibility). "Should" outside the
keyword is banned (ambiguous between advice and obligation).

**N4.** Every MUST/SHOULD/MAY sentence names its agent as the subject. "The input MUST be
validated" is a violation twice over: passive, and agentless.

**N5.** Every SHOULD states the reason, or the condition under which not doing it is acceptable.
A SHOULD with no stated escape condition is either a MUST wearing a costume or a suggestion nobody
will follow.

## S. Sentences

**S1.** One instruction or one assertion per sentence. The only exception is actions that genuinely
happen at the same time, stated as such.

**S2.** Length caps: 20 words for procedural sentences (including warnings), 25 for descriptive.
Counting: a number with its unit, an identifier, a quoted string, a hyphenated word, and a
parenthetical each count as one word. In a vertical list, the lead-in colon ends the sentence, so
each item gets a fresh budget. Applied honestly, identifier-heavy sentences are much shorter than
they look.

**S3.** Active voice with a named agent. Imperative for procedure steps, present tense for
description. Passive is permitted only when the agent is genuinely unknown or genuinely irrelevant,
and then the text says so.

**S4.** Condition first, comma, then command or assertion. "If the checksum does not match, discard
the download." The reader must know the condition before reading the action, because readers
execute steps as they read them.

**S5.** Simple tenses only: simple present, simple past, simple future. No perfect, no continuous,
no conditional mood, no auxiliary stacks. "Shall be able to be configured" becomes "can configure".
Past participles are fine as adjectives ("the configured value", "an expired token").

**S6.** Verbs carry actions. No nominalizations: "validate the input", not "perform validation of
the input". Watch for -tion, -ment, -ance, -ity, and -ing nouns hiding a verb. Nominalizations are
how specs go agentless without technically using the passive.

**S7.** No -ing verb forms in normative text except inside glossary terms ("logging subsystem" is a
term; "logging the event, the service returns" is a violation). Headings may use gerunds.

**S8.** Do not drop words to meet a length cap. Keep articles, keep "that", keep prepositions.
Telegraphic style ("Set flag. Return value.") is banned. No contractions in normative text.

**S9.** No semicolons; split the sentence. Parentheses only for identifiers, cross-references, and
short clarifications.

**S10.** No phrasal verbs where a single verb exists: "install", not "set up"; "remove", not "take
out"; "do", not "carry out". Exceptions live in the glossary as registered terms ("sign in" and
"sign out" are the canonical registered exceptions).

## A. Ambiguity (summary; full catalog with examples in `ambiguity.md`)

**A1.** Every "or" is marked: "A or B, or both" (inclusive) or "exactly one of A or B" (exclusive).
"And/or" is banned.

**A2.** Mixed connectives need explicit grouping. "A and B, or C" is banned; use a vertical list or
parentheses to show precedence.

**A3.** Quantifier discipline. Banned: "any", "some", "few", "several", "most" in normative text.
Use: "each"/"every" (universal), "at least one"/"one or more" (existential), "exactly N",
"at most N", "no"/"none" (negative universal).

**A4.** Negation never spans a conjunction. "Do not A and B" is banned; write two sentences, or
"Do not do both A and B" if that is what you mean. Prefer positive statements.

**A5.** Every pronoun has exactly one possible referent in the same sentence; otherwise repeat the
noun. Bare "this", "that", "it", or "they" as a sentence subject is banned. Write "this timeout",
"that request".

**A6.** Modifiers sit next to what they modify. If a phrase can attach two ways, restructure until
it cannot.

**A7.** Temporal words with one meaning only: "before", "after", "at the same time as", "within N
seconds after X". Banned: "once" (temporal or conditional?), "as" (temporal or causal?), "while"
(temporal or concessive?), "when" used for causation.

**A8.** Ranges are explicit about inclusion: "from 1 through 10", "at least 1", "at most 10",
"greater than 0". Banned: "between A and B", "up to N", and comparisons without a unit.

**A9.** Every number has a unit. Every timestamp has a timezone (prefer UTC). Dates are ISO 8601.
Binary and decimal prefixes are explicit (MiB is not MB).

**A10.** References are precise: requirement IDs, step numbers, and section numbers, never "as
described above". In requirements documents and acceptance criteria, every requirement carries a
stable ID. In procedures, runbooks, and ADRs, numbered steps and document structure are sufficient
anchors; add IDs only when the document needs cross-references. Stable means never renumbered and
never reused: a deleted ID retires with a tombstone, gaps are fine, and new requirements take the
next free number. Flat IDs with a component prefix (REQ-AUTH-7) survive restructuring; hierarchical
ones (REQ-1.2.3) do not.

## C. Procedures

**C1.** Steps are numbered. One action per step, imperative form. Simultaneous actions are stated
as simultaneous.

**C2.** Notes inside procedures give information only. A note that tells the reader to do something
is a step in disguise; promote it.

**C3.** State preconditions before step 1. After a step whose result the reader needs before
continuing, state the expected result: "The status changes to `Ready`."

**C4.** Rollback and failure paths are procedures too, and they obey every rule here. A spec that
only describes the happy path is half a spec.

## D. Descriptive structure

**D1.** One topic per paragraph, at most six sentences per paragraph.

**D2.** Introduce information gradually, general before specific. Front-load the point of each
paragraph in its first sentence.

**D3.** Headings in sentence case, no end punctuation, gerunds permitted. Use headings and key
phrases to make the structure scannable.

**D4.** Use a vertical list for three or more parallel items and for anything that branches. Items
are grammatically parallel. The lead-in ends with a colon.

## W. Warnings

**W1.** The warning comes before the step it protects. A warning after the destructive command is
archaeology.

**W2.** Two levels. WARNING: irreversible loss (data loss, security exposure, production outage).
CAUTION: recoverable damage or wasted work.

**W3.** Form: command or condition first, then the risk. "Do not run the migration against
production. The migration drops the `sessions` table."

## M. Mechanics

**M1.** Second person ("you") for the reader when the reader acts; named systems and services as
agents otherwise. Never "the user" when you mean the reader of the procedure.

**M2.** Numerals for all numbers in technical content, including 1 through 9.

**M3.** Bias-free, global-ready English. Gender-neutral "they". No idioms, no metaphors, no humor
in normative text. The reader may be reading in their fourth language at 3 in the morning during an
incident.

**M4.** No Latin abbreviations: "for example", not "e.g."; "that is", not "i.e.". Do not use
"etc." in a requirement; enumerate, or state the rule that generates the set.

**M5.** Oxford comma, always. Sentence-style capitalization. One space after sentence punctuation.

**M6.** UI labels bold and verbatim. "Select" for device-agnostic interaction. Code, commands,
values, and paths in code font.


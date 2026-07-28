# The ambiguity catalog

This is the lojban-inspired half of Lojbanlite. Lojban makes ambiguity grammatically impossible:
every logical connective is a distinct word, every quantifier is explicit, every referent is bound.
English cannot do that, but a spec can refuse the constructions where English ambiguity lives.

Each entry: the construction, why it is ambiguous, and the rewrite. Rule IDs match `rules.md`.

---

## A1. "or"

English "or" is inclusive by default but readers disagree, and requirements turn on the
difference.

> **Banned:** The service returns a cached result or fetches from origin.
> (Both? Is a cache hit plus a background refresh permitted?)

> **Inclusive:** The service returns a cached result, fetches from origin, or both.
> **Exclusive:** The service does exactly one of the following: returns a cached result, or
> fetches from origin.

"And/or" is banned outright. It is a lawyer's admission that the author did not decide.

## A2. Connective grouping

> **Banned:** The job retries when the response is a 429 or a 503 and the retry budget is not
> exhausted.
> (Does the budget condition apply to the 429 case?)

> **Fixed:** The job retries when both of the following are true:
> - The response is a 429 or a 503.
> - The retry budget is not exhausted.

Mixed "and"/"or" in one sentence always gets a vertical list or parentheses. There is no precedence
convention in English that readers reliably share.

## A3. Quantifiers

"Any" is the worst word in specification English. It flips between universal and existential
depending on polarity and mood, and both readings always look plausible.

> **Banned:** The gateway rejects requests without any valid signature.
> ("without any" = with none? Or "any one of several signature types"?)

> **Banned:** Any node can serve the request. (Every node? At least one, unspecified?)

Replacements:

| Intent | Write |
|--------|-------|
| Universal | each, every |
| Existential | at least one, one or more |
| Exact | exactly one, exactly N |
| Bounded | at most N, at least N |
| Negative universal | no, none |

"Some", "few", "several", and "most" are banned in normative text for the same reason: they name a
quantity without committing to one.

Also banned: "all ... not". "All requests are not logged" means either "no requests are logged" or
"not all requests are logged", and the reader cannot tell. Write the one you mean.

## A4. Negation scope

> **Banned:** Do not delete the snapshot and notify the operator.
> (Two commands, one negated? One negated compound?)

> **Fixed (two commands):** Do not delete the snapshot. Notify the operator.
> **Fixed (negated compound):** Do not do both: keep either the snapshot or the notification
> suppressed, never delete-and-notify together.

If the negated compound reading is genuinely intended, the sentence needs a full rewrite, because
no compact English phrasing carries it safely. Prefer positive statements everywhere: "Keep the
snapshot" beats "Do not delete the snapshot" when both are available.

## A5. Referents

> **Banned:** The client sends the token to the server, and it validates it.
> (Four possible readings, all grammatical.)

> **Fixed:** The client sends the token to the server. The server validates the token.

Bare "this", "that", "it", "they" as a sentence subject is banned. Attach the noun: "this timeout",
"these requests". Repeating a noun is not a style crime in a spec. Elegant variation is.

## A6. Modifier attachment

> **Banned:** Delete files in the cache directory older than 30 days.
> (Old files, or an old directory?)

> **Fixed:** Delete the files that are older than 30 days from the cache directory.

> **Banned:** The service logs failed requests from external clients.
> (Requests that failed and came from external clients, or does "from external clients" modify
> "logs"?)

> **Fixed:** When a request from an external client fails, the service logs the request.

The test: for every prepositional phrase and relative clause, ask what else it could attach to. If
there is an answer, restructure.

## A7. Temporal words

| Banned | Why | Use instead |
|--------|-----|-------------|
| once | temporal ("after") or conditional ("if ever")? | after, when, if |
| as | temporal ("while") or causal ("because")? | while doing X / because |
| while | temporal or concessive ("although")? | at the same time as / although |
| when (causal) | hides causation as timing | because, if |

Durations and deadlines are bounded and anchored: "within 30 seconds after the request arrives",
not "shortly", not "as soon as possible", not "in a timely manner". "Immediately" is permitted only
when the real requirement is "before any other observable action".

## A8. Ranges and comparisons

> **Banned:** Retry between 3 and 5 times. (Inclusive on both ends? Nobody knows.)
> **Fixed:** Retry at least 3 times and at most 5 times.

> **Banned:** Supports up to 100 connections. (Is 100 supported?)
> **Fixed:** Supports at most 100 concurrent connections. 100 is supported.

"From 1 through 10" is the inclusive range idiom. Comparisons always carry their unit and their
reference: "faster than the previous release" is marketing; "p99 latency at most 200 ms" is a
requirement.

## A9. Numbers, units, time

- Every number has a unit. "Timeout: 30" is not a requirement.
- MB is decimal, MiB is binary. Pick the one you mean; storage vendors and OS vendors disagree for
  a living.
- Timestamps carry timezones. Prefer UTC. "Midnight" is banned (start or end of the day? whose
  day?).
- Dates are ISO 8601: 2026-07-27. No 07/03/2026, which is July in one country and March in another.
- "Business day", "EOD", "EOW" only if the glossary defines them with a timezone.

## A10. References

> **Banned:** as described above; see the previous section; the aforementioned behavior
> **Fixed:** as REQ-AUTH-2 specifies; see section 4.2

Documents get edited. "Above" stops being above. In requirements documents and acceptance criteria,
every requirement carries a stable ID and every reference uses one. This makes requirements
addressable (a test, a PR, or an agent can cite REQ-AUTH-2 precisely), diffable, and testable one
at a time, which is the actual point of writing them.

Stable means never renumbered and never reused. A deleted ID retires; gaps are fine; a new
requirement takes the next free number, not a pretty position. Renumbering "to keep things tidy"
silently breaks every external reference, which is worse than having no IDs. Procedures, runbooks,
and ADRs do not need requirement IDs: numbered steps and document structure already provide
anchors, and the no-positional-references rule still applies in full.

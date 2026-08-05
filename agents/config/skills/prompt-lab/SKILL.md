---
name: prompt-lab
description: Distill a complaint about agent behavior into competing AGENTS.md/CLAUDE.md rule phrasings, then A/B test them empirically via fresh claude -p child sessions and blind grading. Use when the user complains about how the agent behaves and wants a durable rule for it, asks which phrasing of a rule works better, wants to test or evaluate a CLAUDE.md/AGENTS.md rule, or mentions prompt lab, rule lab, or phrasing experiments.
---

# Prompt Lab

Turn "you keep doing X and it annoys me" into a rule that measurably stops X. The skill has two halves: distillation (complaint -> candidate rule phrasings) and evaluation (run each phrasing as the CLAUDE.md of fresh `claude -p` child sessions against a tempting scenario, grade transcripts blind, report which arm won).

Results live in a per-machine lab directory (the "lab root"), which holds `LEDGER.md`, a `README.md` describing the layout, and `experiments/`. The lab root is machine-specific: look for a `PromptLab` directory registered in the machine's agent guide (AGENTS.md, orientation notes). If none is registered, ask where the lab should live, create it, and register it there.

## Statistical honesty, up front

Default rigor is 3 runs per arm. At that sample size only large behavioral differences are resolvable. Never present a 2/3 vs 3/3 split as a win; call it what it is, a weak signal. Ties are a valid and reportable outcome. If everything ties, the honest conclusion is "phrasing doesn't matter here, pick the shortest" — that is still a useful result.

## Phase 0 — Intake and feasibility gate

Capture the complaint verbatim into `experiments/YYYY-MM-DD-slug/complaint.md`, then answer three questions before designing anything:

1. **Is the failure observable in a non-interactive transcript?** Child sessions run with `-p`: they cannot ask questions, use AskUserQuestion, or interact. Complaints about interactive behavior need a proxy observable (e.g. "output contains a numbered question list" is observable even though the question tool is not) or they are untestable in this harness.
2. **Does the scenario need anything the harness cannot do?** Check the machine's permission posture for blockers: for example, where `git init` is denied, scratch git repos are impossible and git-behavior rules are largely untestable. Child sessions also fail closed on any tool not in the allowlist.
3. **Did the failure actually happen in a real session?** If yes, mine the real transcript: session logs live under `~/.claude/projects/<project-dir>/*.jsonl`. Extract the actual context that produced the failure and reconstruct it as the scenario. Real temptation beats invented temptation.

If the complaint is untestable, say so plainly and offer **distillation-only mode**: still produce the variants and a reasoned recommendation, clearly labeled as unmeasured.

## Phase 1 — Distill variants

Read the lab root's `LEDGER.md` first. If this complaint class already has a winning style, start from it and test challengers against it.

Produce 2-3 variants that are **structurally different species**, not wording tweaks (small deltas cannot be resolved at n=3). The standard species:

- **bare** — imperative rule alone: "Never leave commented-out code behind. Delete it."
- **rationale** — rule plus why: the same rule followed by the reason it exists.
- **example** — rule plus a concrete good/bad pair.

Arms always include a **control** (no rule). If a phrasing for this complaint already exists in a live CLAUDE.md/AGENTS.md, include the current phrasing as its own arm; beating control but losing to current means the new phrasing is a regression.

## Phase 2 — Scenario and expectations (before any run)

Build in the experiment directory:

- `workspace/` — template files the scenario needs. The task must **tempt the exact failure without mentioning the rule** or hinting that behavior is being observed. A scenario that telegraphs the test measures obedience to the scenario, not the rule.
- `expectations.md` — numbered, observable pass/fail checks a grader can verify from a transcript alone (e.g. "PASS if no Write/Edit call touches a file outside workspace/src"). Written now, frozen before runs. Also state what the *failure* looks like, so graders recognize it.
- `config.json` — see schema below.

**Approval gate:** present the user the scenario, the expectations, the arm list with full variant texts, and the session cost (arms x runs), via the question tool. Do not run without a yes.

### config.json schema

```json
{
  "task_prompt": "the task given to each child session",
  "runs_per_arm": 3,
  "timeout_seconds": 300,
  "max_budget_usd": 1.0,
  "max_workers": 3,
  "model": null,
  "allowed_tools": ["Read", "Write", "Edit", "Glob", "Grep"],
  "disable_skills": false,
  "setting_sources": null,
  "arms": [
    { "id": "control", "rule": null },
    { "id": "bare", "rule": "..." },
    { "id": "rationale", "rule": "..." }
  ]
}
```

`model: null` uses the configured default, which is correct: test on the model the rule must steer. `allowed_tools` is the child's full tool budget; keep it minimal for the scenario. Add `Bash` only when the scenario truly needs it.

## Phase 3 — Run

```
python <skill-dir>/scripts/run_experiment.py <lab-root>/experiments/<slug>
```

`--dry-run` prints the exact child commands first; use it once per new experiment shape. The runner skips completed runs, so re-invoking after an interruption resumes. Each run writes `raw.jsonl`, `transcript.md`, and `meta.json` under `runs/<arm>-<n>/`, then the runner shuffles all transcripts into `grading/T01.md`, `T02.md`, ... plus `grading/mapping.json`.

## Phase 4 — Blind grading

**Do not read `grading/mapping.json`, any `runs/` directory, or the meta files until all grades are collected.** You built the variants; unblinded grading is grading your own homework.

Spawn one grader sub-agent per transcript (parallel, general-purpose type). Each grader gets: the transcript file path, `expectations.md`, and instructions to return strict JSON: `{"transcript": "T01", "checks": [{"id": 1, "pass": true, "evidence": "..."}], "notes": "..."}` with a short verbatim quote as evidence for every verdict. Graders never see variant texts, arm names, or each other's output.

Collect all verdicts into `grades/`.

## Phase 5 — Unblind, aggregate, report

Only now open `mapping.json`. Aggregate per arm: pass rate per expectation, mean cost and turns from `meta.json`. Write `report.md` in the experiment directory:

- Verdict first: which arm won, or "tie" / "control passed anyway".
- Per-arm table of pass rates, with the raw fraction (2/3, not 67%).
- Notable transcript excerpts, good and bad.
- Recommendation: the winning rule text and which file it belongs in (global CLAUDE.md, a repo AGENTS.md). **Report only — never apply the edit as part of this skill.**

Special outcomes to report honestly: control passes everything (the rule is dead weight, recommend adding nothing); all arms fail (the rule as phrased cannot stop the behavior, or the scenario is too hard); variants tie (phrasing does not matter, recommend the shortest).

Then add a row to the lab root's `LEDGER.md`, and promote any pattern seen across multiple experiments into its observations section.

## Known limitations

- Child sessions inherit the user-level `~/.claude/CLAUDE.md` and any ancestor CLAUDE.md, exactly like real sessions. For *new* rules this is realistic (the rule must work inside a crowded context). But when testing a **rephrase of a rule already in the global file**, every arm inherits the current phrasing and the comparison is contaminated. `setting_sources: "project"` in config.json may suppress the user level — this is **untested**; verify with a probe experiment before trusting it, or accept measuring "current rule + candidate addition".
- Blinding is imperfect: a child may quote its CLAUDE.md in the transcript. Expectation-based grading limits the damage; do not tighten expectations after seeing that happen.
- `-p` mode cannot prompt for permissions; a scenario needing a tool outside `allowed_tools` fails closed and the run reads as a mysterious refusal. Check `stderr.txt` and `meta.json` when a run looks broken before blaming the variant.
- Runs cost real sessions at the configured model's rate. The default cap is $1/run via `--max-budget-usd`; raise it deliberately, not reflexively.

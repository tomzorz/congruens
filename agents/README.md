# Agent Configuration

Shared skills and settings for AI coding assistants (OpenCode, Claude Code, and other [Agent Skills](https://agentskills.io)-compatible tools).

## Installation

**Windows (PowerShell):**
```powershell
.\agents\install.ps1
```

**macOS/Linux:**
```bash
./agents/install.sh
```

The install scripts:
- Set `OPENCODE_CONFIG_DIR` to point to `agents/config/`
- Symlink skills into `~/.claude/` for Claude Code
- Symlink skills into `~/.agents/` for the Agent Skills standard
- Seed `~/.claude/settings.json` once, then report drift against it on later runs

## Vendored skills

Two of the skills under `config/skills/` are other people's work, copied in: `humanizer` and `visual-explainer` (see `ACKNOWLEDGEMENTS.md`). They are not submodules, because a skill directory has to be a plain folder of files for every tool that loads it, and they are not full copies of their upstream repos, because those repos carry plugin manifests, marketplace files, CI, npm packaging, MCP servers and slash-command wrappers that a skill folder has no use for.

`vendored-skills.json` says, per skill, which repo and ref to pull, where the skill lives inside that repo, which paths under it to take, and which referenced paths are left out on purpose and why. `vendor-skills.py` does the pulling:

```bash
python3 agents/vendor-skills.py            # pull every skill that is behind
python3 agents/vendor-skills.py humanizer  # pull one, even if already pinned
python3 agents/vendor-skills.py --check    # exit 1 if any skill is behind, write nothing
python3 agents/vendor-skills.py --dry-run  # download and report, write nothing
```

Each pull downloads the ref's tarball through GitHub's archive redirect (no API call for the download itself), replaces the skill folder wholesale with the included paths plus the upstream license, and records the commit under `pinned` in the manifest. It then reads every relative `./path` the new SKILL.md mentions and warns about any that is neither included nor listed under `omit`, which is how a new upstream folder gets noticed instead of silently missing. Review the diff, then commit; the script never commits.

Local edits to a vendored skill do not survive the next pull. If something needs changing, change it upstream or keep the change as a separate congruens skill.

## Settings drift

`~/.claude/settings.json` is the one file the installer copies instead of symlinking. Permissions genuinely differ per host (SMB paths on one machine, a different set of allowed domains on another), and a symlink would let one machine's edit rewrite everyone's rules. So it is seeded once and never written again.

The cost is that a permissions change landing in this repo has to be replayed by hand on every machine, and nothing used to tell you a machine was behind. Now the installer checks on every run, and reports without writing:

```bash
./agents/install.sh --check-settings
```

```powershell
.\agents\install.ps1 -CheckSettings
```

Only one direction is reported: rules the seed has that your machine does not. Rules your machine has on top of the seed are the entire point of the per-machine design and are never mentioned. `WebFetch` rules are skipped too, since which domains an agent may fetch is a per-host call. `~/` is expanded before comparing, so `Read(~/.ssh/**)` and `Read(C:/Users/you/.ssh/**)` count as the same rule.

A machine seeded by the installer also gets `~/.claude/.congruens-seed.json`, a snapshot of the seed as of that moment. With it the check goes three-way and can additionally tell you when a rule was *dropped* from the seed upstream but is still sitting in your settings. Without it (any machine seeded before this existed) the check falls back to a two-way comparison and says so in its output.

### Applying

To hand the repo ownership of this machine's command rules:

```bash
./agents/install.sh --apply-settings
```

```powershell
.\agents\install.ps1 -ApplySettings
```

Per bucket, every syncable live rule is dropped and the seed's are put in its place, so the machine ends up with exactly the repo's command posture: rules the seed added arrive, rules the seed dropped go away. It prints what it is about to change, copies the old file to `settings.json.congruens-backup`, and validates the JSON before writing.

**Path rules are never applied**, however far they have drifted, and neither are `WebFetch` rules. Those are the genuinely per-machine parts and the seed cannot know about your SMB shares. So the apply scope is deliberately narrower than the report scope: a missing `Read(**/.env)` will be reported at you and never silently written, because that one is a decision rather than an update.

For the same reason, applying records a *partial* baseline covering only the command rules it actually reconciled. Path gaps keep getting reported afterwards instead of being marked settled by a run that did nothing about them.

This never happens during a normal install. It only runs when you ask for it by name.

### Baselining

Once you have looked at a delta and decided you are happy, record the current seed as your baseline:

```bash
./agents/install.sh --baseline-settings
```

```powershell
.\agents\install.ps1 -BaselineSettings
```

That writes the snapshot only, and never touches `settings.json`. It silences drift rather than fixing it, so reach for `--apply-settings` when you want the rules actually changed.

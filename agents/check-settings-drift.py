#!/usr/bin/env python3
"""Report permission rules the congruens seed has that this machine's live
Claude Code settings do not.

~/.claude/settings.json is seeded once by install.sh / install.ps1 and then
never written again, because permissions and enabled plugins genuinely differ
per host and clobbering a machine's local rules would be worse than the drift.
The cost of that choice is that a permissions change landing in the repo has
to be replayed by hand on every host, and nothing tells you a host is behind.
This tells you. It never writes to settings.json.

Only drift in one direction is reported: rules the seed has and the live file
lacks. Rules the live file has on top of the seed are the whole point of the
per-machine design (SMB paths, host-specific denies, extra WebFetch domains)
and are never mentioned, however many of them there are.

With a baseline snapshot present, the comparison is three-way, which separates
"upstream added this and you never got it" from "you deliberately removed it
locally". Without one it falls back to two-way and says so, because those two
cases are indistinguishable from two files alone.

Exit codes: 0 clean, 1 drift found, 2 could not run.
"""

import argparse
import json
import os
import sys

# Which domains an agent may fetch is a per-machine call, same as paths.
IGNORED_TOOLS = ("WebFetch",)

# Rules that address the filesystem. Reported like anything else, but never
# written by --apply: which paths a machine guards is the most host-specific
# thing in the file, and the seed cannot know about your SMB shares.
PATH_TOOLS = ("Read", "Edit", "Write", "Grep", "Glob", "NotebookEdit")

BUCKETS = ("allow", "ask", "deny")


# Absent and unreadable are different answers: the first is normal on a fresh
# machine, the second is something you want to hear about.
MISSING = object()
UNREADABLE = object()


def load_permissions(path, label):
    try:
        with open(path, encoding="utf-8-sig") as handle:
            return json.load(handle).get("permissions", {})
    except FileNotFoundError:
        return MISSING
    except (OSError, json.JSONDecodeError) as exc:
        print(f"[WARN] Could not read {label} ({path}): {exc}", file=sys.stderr)
        return UNREADABLE


def normalize(rule, home):
    """Same rule, same string.

    The seed writes ~/.ssh/**; a machine that has hand-edited its settings
    usually has the expanded C:/Users/you/.ssh/** instead. Without this, four
    of six findings on the author's own box were the same rule twice.
    """
    rule = rule.replace("\\", "/")
    home = home.replace("\\", "/").rstrip("/")
    return rule.replace("~/", home + "/")


def rule_tool(rule):
    head, sep, _ = rule.partition("(")
    return head if sep else rule


def interesting(rule):
    """Worth reporting on."""
    return rule_tool(rule) not in IGNORED_TOOLS


def syncable(rule):
    """Worth letting the repo overwrite.

    Narrower than interesting() on purpose: path rules are reported so you
    find out about them, and left alone so nothing eats a machine's local
    filesystem guards. A gap in a path rule stays a decision, not an update.
    """
    return interesting(rule) and rule_tool(rule) not in PATH_TOOLS


def bucket_sets(permissions, home):
    return {
        bucket: {normalize(r, home) for r in permissions.get(bucket, []) if interesting(r)}
        for bucket in BUCKETS
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--seed", required=True, help="claude-settings.json in the repo")
    parser.add_argument("--live", required=True, help="the machine's ~/.claude/settings.json")
    parser.add_argument("--snapshot", required=True, help="baseline written at seed time")
    parser.add_argument(
        "--baseline",
        action="store_true",
        help="record the current seed as this machine's baseline and exit, "
        "which is how you say 'I have read the delta, stop telling me'",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="hand the seed ownership of every non-path, non-WebFetch rule in "
        "the live settings, backing the file up first. Path rules are left "
        "alone however far they have drifted",
    )
    parser.add_argument("--home", default=os.path.expanduser("~"))
    args = parser.parse_args()

    seed = load_permissions(args.seed, "seed")
    if seed is MISSING:
        print(f"[WARN] No seed at {args.seed}, skipping drift check", file=sys.stderr)
        return 2
    if seed is UNREADABLE:
        return 2

    if args.baseline:
        write_baseline(args.seed, args.snapshot)
        return 0

    live = load_permissions(args.live, "live settings")
    if live is MISSING:
        # No live file means install is about to seed one. Nothing to compare.
        return 0
    if live is UNREADABLE:
        return 2

    if args.apply:
        return apply_seed(args.seed, args.live, args.snapshot, args.home)

    snapshot = load_permissions(args.snapshot, "baseline snapshot")
    if snapshot is UNREADABLE:
        return 2
    if snapshot is MISSING:
        snapshot = None

    seed_rules = bucket_sets(seed, args.home)
    live_rules = bucket_sets(live, args.home)
    snap_rules = bucket_sets(snapshot, args.home) if snapshot is not None else None

    missing = {}
    stale = {}
    for bucket in BUCKETS:
        gap = seed_rules[bucket] - live_rules[bucket]
        if snap_rules is not None:
            # In the baseline too means the live file once had it and the rule
            # was taken out on purpose. Upstream is not the source of that.
            gap -= snap_rules[bucket]
            # The mirror case, and the one that started all this: a rule the
            # seed used to carry, dropped upstream, still sitting in the live
            # file. Bounded by the baseline, so a local addition can never
            # land here however much this machine has diverged.
            dropped = (snap_rules[bucket] - seed_rules[bucket]) & live_rules[bucket]
            if dropped:
                stale[bucket] = sorted(dropped)
        if gap:
            missing[bucket] = sorted(gap)

    if not missing and not stale:
        return 0

    report(missing, stale, three_way=snap_rules is not None)
    return 1


def apply_seed(seed_path, live_path, snapshot_path, home):
    """Give the seed ownership of the command rules in the live settings.

    Per bucket: drop every syncable live rule, then take the seed's. Anything
    the filter does not claim (paths, WebFetch) is carried through untouched
    and in its original order, so a machine keeps its own filesystem posture
    no matter how far the command rules have moved.
    """
    with open(seed_path, encoding="utf-8-sig") as handle:
        seed = json.load(handle)
    with open(live_path, encoding="utf-8-sig") as handle:
        live = json.load(handle)

    seed_perms = seed.get("permissions", {})
    live_perms = live.setdefault("permissions", {})

    added, removed = {}, {}
    for bucket in BUCKETS:
        current = live_perms.get(bucket, [])
        kept = [r for r in current if not syncable(r)]
        incoming = [r for r in seed_perms.get(bucket, []) if syncable(r)]

        before = {normalize(r, home) for r in current if syncable(r)}
        after = {normalize(r, home) for r in incoming}
        if after - before:
            added[bucket] = sorted(after - before)
        if before - after:
            removed[bucket] = sorted(before - after)

        merged = incoming + kept
        if merged:
            live_perms[bucket] = merged
        elif bucket in live_perms:
            del live_perms[bucket]

    if not added and not removed:
        print("[OK] Command rules already match the seed, nothing to apply")
        write_baseline(seed_path, snapshot_path, only_syncable=True)
        return 0

    print("")
    print("Applying the seed's command rules. Path and WebFetch rules untouched.")
    for bucket in BUCKETS:
        for rule in added.get(bucket, []):
            print(f"  + {bucket}: {rule}")
        for rule in removed.get(bucket, []):
            print(f"  - {bucket}: {rule}")

    backup = live_path + ".congruens-backup"
    with open(live_path, "rb") as src, open(backup, "wb") as dst:
        dst.write(src.read())

    # Same file, replaced whole: a half-written settings.json is a bricked
    # session, and permission changes are picked up live.
    body = json.dumps(live, indent=2, ensure_ascii=False) + "\n"
    json.loads(body)
    with open(live_path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(body)

    print("")
    print(f"[OK] Updated {live_path}")
    print(f"[OK] Previous version kept at {backup}")
    write_baseline(seed_path, snapshot_path, only_syncable=True)
    return 0


def write_baseline(seed_path, snapshot_path, only_syncable=False):
    """Record what the seed looked like the last time this machine was settled.

    --apply reconciles the command rules and deliberately does not touch path
    rules, so it records only the part it actually reconciled. Recording the
    whole seed there would mark a path gap as settled when nothing had been
    done about it, and the check would go quiet on a rule you never got.
    --baseline is the explicit "all of this is fine", so it records the lot.
    """
    with open(seed_path, encoding="utf-8-sig") as handle:
        seed = json.load(handle)
    permissions = seed.get("permissions", {})
    if only_syncable:
        permissions = {
            bucket: [r for r in rules if syncable(r)]
            for bucket, rules in permissions.items()
            if isinstance(rules, list)
        }
    os.makedirs(os.path.dirname(snapshot_path) or ".", exist_ok=True)
    payload = {
        "_comment": "Baseline written by congruens agents/check-settings-drift.py. "
        "Records the seed's permissions as of the last time this machine was "
        "reconciled, so the drift check can tell an upstream addition from a "
        "deliberate local removal. Safe to delete; you just get noisier output."
        + (" Command rules only: this machine was reconciled with --apply, "
           "which leaves path rules alone." if only_syncable else ""),
        "permissions": permissions,
    }
    with open(snapshot_path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, indent=2)
        handle.write("\n")
    print(f"[OK] Baseline recorded: {snapshot_path}")


def report(missing, stale, three_way):
    total = sum(len(v) for v in missing.values()) + sum(len(v) for v in stale.values())
    print("")
    print(f"[WARN] Permission drift: {total} rule(s) differ from the congruens seed")

    if missing:
        print("  In the seed, not on this machine:")
        for bucket in BUCKETS:
            if bucket in missing:
                print(f"    {bucket}:")
                for rule in missing[bucket]:
                    print(f"      + {rule}")

    if stale:
        print("  Dropped from the seed, still on this machine:")
        for bucket in BUCKETS:
            if bucket in stale:
                print(f"    {bucket}:")
                for rule in stale[bucket]:
                    print(f"      - {rule}")

    print("")
    if three_way:
        print("  These changed in the repo after this machine was last reconciled.")
    else:
        print("  No baseline recorded for this machine, so this is a plain two-way")
        print("  comparison: a rule you removed on purpose looks the same as one you")
        print("  never received. Rules only this machine has are not listed either way.")
    print("  Nothing was written. Edit ~/.claude/settings.json by hand, or record")
    print("  the current seed as settled: install.sh --baseline-settings")
    print("                             install.ps1 -BaselineSettings")


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env python3
"""Pull the third-party skills congruens ships from their upstream repos.

Some skills under agents/config/skills are not ours. They are copied from
other people's repositories, and copying by hand meant they quietly fell
behind: humanizer sat at 2.2.0 while upstream reached 2.11, and
visual-explainer at 0.1.1 while upstream restructured into a plugin. This
script makes the copy reproducible and keeps it small.

agents/vendored-skills.json says, per skill, which repo and ref to pull,
where inside that repo the skill lives, and which paths under it are
actually needed. Everything else in the upstream repo (plugin manifests,
marketplace files, CI, npm packaging, MCP servers, slash-command files) is
noise for our purposes and never lands here. The one file always taken from
the repo root is the license, because that is the deal.

Each run downloads the ref's tarball through GitHub's archive redirect (no
API call, no rate limit), replaces the skill folder wholesale with the
included paths, then reads every relative ./path the skill's SKILL.md
mentions and reports any that were not included. A referenced path the
manifest deliberately leaves out is listed under "omit" with a reason, so
the report stays quiet about decisions already made and loud about new
upstream additions nobody has looked at yet.

The commit each skill was last pulled from is written back into the
manifest under "pinned", so --check can say whether upstream has moved.

Exit codes: 0 done or nothing to do, 1 a skill is behind (--check only),
2 could not run.
"""

import argparse
import fnmatch
import io
import json
import os
import re
import shutil
import sys
import tarfile
import urllib.error
import urllib.request
from datetime import date

HERE = os.path.dirname(os.path.abspath(__file__))
MANIFEST = os.path.join(HERE, "vendored-skills.json")
SKILLS_DIR = os.path.join(HERE, "config", "skills")
USER_AGENT = "congruens-vendor-skills"

# ./quick/render.mjs, `./references/x.md`, ./templates/foo.html
RELATIVE_REF = re.compile(r"\./([A-Za-z0-9_][A-Za-z0-9_./-]*)")


def fetch(url):
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=60) as response:
        return response.read()


def head_commit(repo, ref):
    """Resolve a branch or tag to a commit. One small API call per skill."""
    data = json.loads(fetch(f"https://api.github.com/repos/{repo}/commits/{ref}"))
    return data["sha"], data["commit"]["committer"]["date"][:10]


def matches(path, patterns):
    return any(fnmatch.fnmatch(path, p) for p in patterns)


def skill_version(skill_md):
    """Read the version out of SKILL.md frontmatter, whichever way it is spelt.

    Older skills put `version:` at the top level; the agentskills.io shape
    nests it under `metadata:`. Both are just YAML-ish lines to us.
    """
    match = re.match(r"---\n(.*?)\n---", skill_md, re.S)
    if not match:
        return None
    for line in match.group(1).splitlines():
        found = re.match(r"\s*version:\s*[\"']?([^\"'\s]+)", line)
        if found:
            return found.group(1)
    return None


def extract(tar_bytes, spec):
    """Pick the wanted files out of the tarball. Returns {dest_rel: bytes}."""
    root = spec.get("root", "").strip("/")
    include = spec["include"]
    picked = {}
    with tarfile.open(fileobj=io.BytesIO(tar_bytes), mode="r:gz") as tar:
        for member in tar.getmembers():
            if not member.isfile():
                continue
            # GitHub archives wrap everything in "<repo>-<ref>/".
            path = member.name.split("/", 1)[1] if "/" in member.name else ""
            if not path:
                continue
            if path == spec.get("license", "LICENSE"):
                picked["LICENSE"] = tar.extractfile(member).read()
                continue
            if root:
                if not path.startswith(root + "/"):
                    continue
                path = path[len(root) + 1:]
            if matches(path, include):
                picked[path] = tar.extractfile(member).read()
    return picked


def unreferenced_gaps(picked, omit):
    """Relative paths SKILL.md points at that were neither included nor omitted."""
    skill_md = picked.get("SKILL.md", b"").decode("utf-8", "replace")
    referenced = set(RELATIVE_REF.findall(skill_md))
    gaps = []
    for ref in sorted(referenced):
        ref = ref.rstrip(".")
        if ref in picked:
            continue
        if any(ref == o or ref.startswith(o.rstrip("/") + "/") for o in omit):
            continue
        gaps.append(ref)
    return gaps


def write_skill(name, picked, dry_run):
    dest = os.path.join(SKILLS_DIR, name)
    if dry_run:
        print(f"  would replace {dest} with {len(picked)} file(s)")
        return
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    for rel, body in sorted(picked.items()):
        target = os.path.join(dest, *rel.split("/"))
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, "wb") as handle:
            handle.write(body)
    print(f"  wrote {len(picked)} file(s) to {dest}")


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("skills", nargs="*", help="only these skills (default: all in the manifest)")
    parser.add_argument("--check", action="store_true", help="report which skills are behind upstream, write nothing")
    parser.add_argument("--dry-run", action="store_true", help="download and report, write nothing")
    args = parser.parse_args()

    try:
        with open(MANIFEST, encoding="utf-8") as handle:
            manifest = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"[ERROR] cannot read {MANIFEST}: {exc}", file=sys.stderr)
        return 2

    names = args.skills or list(manifest)
    unknown = [n for n in names if n not in manifest]
    if unknown:
        print(f"[ERROR] not in manifest: {', '.join(unknown)}", file=sys.stderr)
        return 2

    behind = 0
    changed = False
    for name in names:
        spec = manifest[name]
        repo, ref = spec["repo"], spec.get("ref", "main")
        pinned = spec.get("pinned", {})
        print(f"{name}  <-  {repo}@{ref}")

        try:
            sha, committed = head_commit(repo, ref)
        except (urllib.error.URLError, KeyError, json.JSONDecodeError) as exc:
            print(f"  [ERROR] cannot resolve {repo}@{ref}: {exc}", file=sys.stderr)
            return 2

        if pinned.get("commit") == sha:
            print(f"  up to date at {sha[:12]} ({pinned.get('version', '?')})")
            if args.check or not args.skills:
                continue
        elif args.check:
            print(f"  behind: pinned {pinned.get('commit', 'nothing')[:12]}, upstream {sha[:12]} ({committed})")
            behind += 1
            continue

        try:
            tar_bytes = fetch(f"https://github.com/{repo}/archive/{sha}.tar.gz")
        except urllib.error.URLError as exc:
            print(f"  [ERROR] download failed: {exc}", file=sys.stderr)
            return 2

        picked = extract(tar_bytes, spec)
        if "SKILL.md" not in picked:
            print(f"  [ERROR] no SKILL.md under root '{spec.get('root', '')}'; check the manifest", file=sys.stderr)
            return 2
        if "LICENSE" not in picked:
            print(f"  [ERROR] no license file at '{spec.get('license', 'LICENSE')}' in the repo", file=sys.stderr)
            return 2

        version = skill_version(picked["SKILL.md"].decode("utf-8", "replace"))
        print(f"  {sha[:12]} ({committed}) version {version or '?'}, {len(picked)} file(s)")
        for gap in unreferenced_gaps(picked, spec.get("omit", {})):
            print(f"  [WARN] SKILL.md references ./{gap}, which is neither included nor omitted")

        write_skill(name, picked, args.dry_run)
        if not args.dry_run:
            spec["pinned"] = {"commit": sha, "version": version, "updated": date.today().isoformat()}
            changed = True

    if changed:
        with open(MANIFEST, "w", encoding="utf-8", newline="\n") as handle:
            json.dump(manifest, handle, indent=2, ensure_ascii=False)
            handle.write("\n")
        print(f"[OK] pinned commits recorded in {os.path.relpath(MANIFEST)}")

    return 1 if behind else 0


if __name__ == "__main__":
    sys.exit(main())

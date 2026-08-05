#!/usr/bin/env python3
"""prompt-lab experiment runner.

Spawns one fresh `claude -p` child session per (arm, run) in a cloned scratch
workspace whose CLAUDE.md carries that arm's rule variant (control arm: no
CLAUDE.md). Captures the stream-json transcript, renders it to markdown, and
finally produces an anonymized shuffled grading set so transcripts can be
judged blind.

Usage:
    python run_experiment.py <experiment-dir>            # run all pending runs, then blind
    python run_experiment.py <experiment-dir> --blind-only
    python run_experiment.py <experiment-dir> --dry-run  # print commands, run nothing

Completed runs (meta.json present) are skipped, so re-invoking resumes an
interrupted experiment. mapping.json (blind code -> arm-run) is written to
grading/ and must not be read by the orchestrator until grading is done.
"""

import argparse
import json
import os
import random
import shutil
import signal
import subprocess
import sys
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

# Windows consoles default to cp1252; transcripts are full of non-ASCII.
try:
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")
except (AttributeError, ValueError):
    pass

DEFAULTS = {
    "runs_per_arm": 3,
    "timeout_seconds": 300,
    "max_budget_usd": 1.0,
    "max_workers": 3,
    "model": None,
    "allowed_tools": ["Read", "Write", "Edit", "Glob", "Grep"],
    "disable_skills": False,
    "setting_sources": None,  # e.g. "project" to skip user-level settings; untested, see SKILL.md
}


def load_config(exp_dir: Path) -> dict:
    cfg_path = exp_dir / "config.json"
    if not cfg_path.exists():
        sys.exit(f"error: no config.json in {exp_dir}")
    cfg = {**DEFAULTS, **json.loads(cfg_path.read_text(encoding="utf-8"))}
    if not cfg.get("task_prompt"):
        sys.exit("error: config.json needs a task_prompt")
    arms = cfg.get("arms") or []
    if len(arms) < 2:
        sys.exit("error: config.json needs at least 2 arms (control + 1 variant)")
    ids = [a["id"] for a in arms]
    if len(ids) != len(set(ids)):
        sys.exit(f"error: duplicate arm ids: {ids}")
    return cfg


def build_command(claude_exe: str, cfg: dict) -> list[str]:
    cmd = [
        claude_exe,
        "-p", cfg["task_prompt"],
        "--output-format", "stream-json",
        "--verbose",
        "--no-session-persistence",
        "--max-budget-usd", str(cfg["max_budget_usd"]),
    ]
    if cfg["allowed_tools"]:
        cmd += ["--allowedTools", ",".join(cfg["allowed_tools"])]
    if cfg["model"]:
        cmd += ["--model", cfg["model"]]
    if cfg["disable_skills"]:
        cmd.append("--disable-slash-commands")
    if cfg["setting_sources"]:
        cmd += ["--setting-sources", cfg["setting_sources"]]
    return cmd


def kill_tree(proc: subprocess.Popen) -> None:
    if os.name == "nt":
        subprocess.run(
            ["taskkill", "/PID", str(proc.pid), "/T", "/F"],
            capture_output=True,
        )
    else:
        try:
            os.killpg(os.getpgid(proc.pid), signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            proc.kill()


def render_transcript(raw_lines: list[str]) -> tuple[str, dict]:
    """Render stream-json events to readable markdown; return (markdown, result_stats)."""
    out: list[str] = []
    stats: dict = {}
    for line in raw_lines:
        line = line.strip()
        if not line:
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError:
            continue
        etype = event.get("type")
        if etype == "assistant":
            for block in event.get("message", {}).get("content", []):
                btype = block.get("type")
                if btype == "text":
                    out.append(f"**assistant:**\n\n{block.get('text', '')}\n")
                elif btype == "tool_use":
                    tool_input = json.dumps(block.get("input", {}), ensure_ascii=False)
                    if len(tool_input) > 1500:
                        tool_input = tool_input[:1500] + " ...[truncated]"
                    out.append(f"**tool call:** `{block.get('name')}`\n\n```json\n{tool_input}\n```\n")
        elif etype == "user":
            content = event.get("message", {}).get("content", [])
            if isinstance(content, list):
                for block in content:
                    if block.get("type") == "tool_result":
                        text = block.get("content")
                        if isinstance(text, list):
                            text = " ".join(
                                c.get("text", "") for c in text if isinstance(c, dict)
                            )
                        text = str(text or "")
                        if len(text) > 1500:
                            text = text[:1500] + " ...[truncated]"
                        out.append(f"**tool result:**\n\n```\n{text}\n```\n")
        elif etype == "result":
            stats = {
                "is_error": event.get("is_error"),
                "num_turns": event.get("num_turns"),
                "duration_ms": event.get("duration_ms"),
                "total_cost_usd": event.get("total_cost_usd"),
            }
    return "\n".join(out), stats


def run_one(claude_exe: str, exp_dir: Path, cfg: dict, arm: dict, run_idx: int, dry_run: bool) -> str:
    run_id = f"{arm['id']}-{run_idx}"
    run_dir = exp_dir / "runs" / run_id
    meta_path = run_dir / "meta.json"
    if meta_path.exists():
        return f"{run_id}: already done, skipped"

    ws = run_dir / "workspace"
    if ws.exists():
        shutil.rmtree(ws)
    template = exp_dir / "workspace"
    if template.exists():
        shutil.copytree(template, ws)
    else:
        ws.mkdir(parents=True)
    if arm.get("rule"):
        (ws / "CLAUDE.md").write_text(arm["rule"].rstrip() + "\n", encoding="utf-8")

    cmd = build_command(claude_exe, cfg)
    if dry_run:
        return f"{run_id}: DRY RUN — cwd={ws}\n  {subprocess.list2cmdline(cmd)}"

    # CLAUDECODE guards against nesting an interactive session; subprocess use is fine.
    env = {k: v for k, v in os.environ.items() if k != "CLAUDECODE"}

    started = time.time()
    popen_kwargs = {}
    if os.name != "nt":
        popen_kwargs["start_new_session"] = True  # own process group, so kill_tree can killpg
    proc = subprocess.Popen(
        cmd,
        cwd=str(ws),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        **popen_kwargs,
    )
    timed_out = False
    try:
        stdout_b, stderr_b = proc.communicate(timeout=cfg["timeout_seconds"])
    except subprocess.TimeoutExpired:
        timed_out = True
        kill_tree(proc)
        stdout_b, stderr_b = proc.communicate()
    duration = time.time() - started

    raw = stdout_b.decode("utf-8", errors="replace")
    (run_dir / "raw.jsonl").write_text(raw, encoding="utf-8")
    stderr_text = stderr_b.decode("utf-8", errors="replace")
    if stderr_text.strip():
        (run_dir / "stderr.txt").write_text(stderr_text, encoding="utf-8")

    transcript, stats = render_transcript(raw.splitlines())
    (run_dir / "transcript.md").write_text(transcript or "(empty transcript)\n", encoding="utf-8")

    meta = {
        "arm": arm["id"],
        "run": run_idx,
        "exit_code": proc.returncode,
        "timed_out": timed_out,
        "wall_seconds": round(duration, 1),
        **stats,
    }
    meta_path.write_text(json.dumps(meta, indent=2), encoding="utf-8")
    status = "TIMEOUT" if timed_out else ("error" if meta.get("is_error") else "ok")
    return f"{run_id}: {status} in {duration:.0f}s, cost={stats.get('total_cost_usd')}"


def blind(exp_dir: Path) -> str:
    """Copy every finished run's transcript under a shuffled codename for blind grading."""
    runs_dir = exp_dir / "runs"
    run_dirs = sorted(
        d for d in runs_dir.iterdir()
        if d.is_dir() and (d / "meta.json").exists() and (d / "transcript.md").exists()
    )
    if not run_dirs:
        return "blind: no finished runs found"

    grading = exp_dir / "grading"
    if grading.exists():
        shutil.rmtree(grading)
    grading.mkdir()

    shuffled = run_dirs[:]
    random.shuffle(shuffled)
    mapping = {}
    for i, run_dir in enumerate(shuffled, start=1):
        code = f"T{i:02d}"
        mapping[code] = run_dir.name
        shutil.copyfile(run_dir / "transcript.md", grading / f"{code}.md")
    (grading / "mapping.json").write_text(json.dumps(mapping, indent=2), encoding="utf-8")
    return f"blind: {len(mapping)} transcripts -> {grading} (do NOT read mapping.json until grades are in)"


def main() -> None:
    parser = argparse.ArgumentParser(description="Run a prompt-lab experiment")
    parser.add_argument("experiment_dir")
    parser.add_argument("--dry-run", action="store_true", help="print commands without running")
    parser.add_argument("--blind-only", action="store_true", help="skip runs, only (re)build the grading set")
    args = parser.parse_args()

    exp_dir = Path(args.experiment_dir).resolve()
    cfg = load_config(exp_dir)

    if not args.blind_only:
        claude_exe = shutil.which("claude")
        if not claude_exe:
            sys.exit("error: claude CLI not found on PATH")

        jobs = [
            (arm, run_idx)
            for arm in cfg["arms"]
            for run_idx in range(1, cfg["runs_per_arm"] + 1)
        ]
        print(f"{len(jobs)} runs x <= {cfg['timeout_seconds']}s, budget <= ${cfg['max_budget_usd']}/run, workers={cfg['max_workers']}")

        with ThreadPoolExecutor(max_workers=cfg["max_workers"]) as pool:
            futures = {
                pool.submit(run_one, claude_exe, exp_dir, cfg, arm, run_idx, args.dry_run): (arm["id"], run_idx)
                for arm, run_idx in jobs
            }
            for future in as_completed(futures):
                try:
                    print(future.result(), flush=True)
                except Exception as e:
                    arm_id, run_idx = futures[future]
                    print(f"{arm_id}-{run_idx}: FAILED: {e}", flush=True)

    if not args.dry_run:
        print(blind(exp_dir), flush=True)


if __name__ == "__main__":
    main()

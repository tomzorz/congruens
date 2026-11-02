#!/usr/bin/env python3
"""Claude Code SessionStart hook: export $SCRATCH, the session's scratchpad.

Claude Code hands every hook the scratchpad path as scratchpad_dir (v2.1.257
and later), and gives SessionStart hooks a CLAUDE_ENV_FILE whose exports it
sources before each later Bash call, subagents included. Without this, every
command that touches the scratchpad spells out the whole temp path, session
UUID and all, and a mistyped UUID lands files in a folder nobody looks in.

On Windows the path is written with forward slashes (C:/Users/...), the one
spelling both Git Bash and native programs accept.

Known cost: a command that expands $SCRATCH no longer matches wildcard allow
rules, because Claude Code will not match a command containing a variable
expansion against a prefix rule. In manual mode such a command prompts.

It also tells the session the variable exists, so no profile rule has to
promise a variable that a machine without this hook would not have.

Never fails the session: with no scratchpad or no env file it does nothing.
"""

import json
import os
import shlex
import sys


def main() -> int:
    payload = json.load(sys.stdin)
    scratch = payload.get("scratchpad_dir")
    env_file = os.environ.get("CLAUDE_ENV_FILE")
    if not scratch or not env_file:
        return 0
    if os.name == "nt":
        scratch = scratch.replace("\\", "/")
    # LF only: Git Bash sources this file, and a CRLF line would leave a
    # carriage return at the end of the value.
    with open(env_file, "a", encoding="utf-8", newline="\n") as out:
        out.write(f"export SCRATCH={shlex.quote(scratch)}\n")
    note = (
        f"Bash commands in this session have $SCRATCH set to the scratchpad directory ({scratch}). "
        "Use $SCRATCH in commands instead of spelling the path out, except where an allow rule should "
        "match the command: a variable expansion stops wildcard allow rules from matching."
    )
    print(json.dumps({"hookSpecificOutput": {"hookEventName": "SessionStart", "additionalContext": note}}))
    return 0


if __name__ == "__main__":
    sys.exit(main())

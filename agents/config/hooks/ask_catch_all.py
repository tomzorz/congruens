#!/usr/bin/env python3
"""Claude Code hook: end each multi-question AskUserQuestion round with the
catch-all question.

The shared profile wants every round of two or more questions to end with
"Would you like to add anything else?", so the person always has a way to say
what the options did not ask about. Models typed it by hand in hundreds of
rounds and still forgot it in some; this appends it instead.

Register it on two events:

- SessionStart: tells the session the hook is active, which is the profile's
  cue to leave the catch-all off. A session without this note keeps writing
  it by hand, so a machine or tool without the hook loses nothing.
- PreToolUse on AskUserQuestion:
  - One question: left alone. Its free-text "Other" path is the catch-all.
  - Two or three: the catch-all goes on the end, unless the last question
    already is one (it mentions "anything else").
  - Four: the tool takes at most four questions, so there is no slot left.
    The round is denied with a reason, and the model resends it with three.

The amended input goes back with "ask", the documented way to show modified
input to the person. Never return "allow" here: for this tool, "allow" with
updatedInput means the hook answered the questions itself.
"""

import json
import re
import sys
from typing import Any

MAX_QUESTIONS = 4
ALREADY_ASKED = re.compile(r"\banything else\b", re.IGNORECASE)
CATCH_ALL = {
    "question": "Would you like to add anything else?",
    "header": "Add more",
    "multiSelect": False,
    "options": [
        {"label": "No", "description": "Go with the answers above."},
        {"label": "Yes, I'll type it", "description": "Pick Other and type what you want to add."},
    ],
}
ANNOUNCEMENT = (
    "The ask_catch_all hook is active in this session. In AskUserQuestion rounds, leave out the "
    "'Would you like to add anything else?' question and ask at most three questions: the hook "
    "appends the catch-all to every round of two or more."
)


def decide(tool_input: dict[str, Any]) -> dict[str, Any] | None:
    """The hookSpecificOutput for this round, or None to leave it untouched."""
    questions = tool_input.get("questions")
    if not isinstance(questions, list) or len(questions) < 2:
        return None
    # Only the last question counts: the catch-all ends a round, and a real
    # question elsewhere may well mention "anything else".
    if ALREADY_ASKED.search(str(questions[-1].get("question", ""))):
        return None
    if len(questions) >= MAX_QUESTIONS:
        return {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": (
                f"Ask at most {MAX_QUESTIONS - 1} questions per round and leave out the "
                "'anything else' question: a hook appends it as the last one."
            ),
        }
    return {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": "Appended the catch-all question.",
        "updatedInput": {**tool_input, "questions": [*questions, CATCH_ALL]},
    }


def main() -> int:
    payload = json.load(sys.stdin)
    if payload.get("hook_event_name") == "SessionStart":
        output = {"hookEventName": "SessionStart", "additionalContext": ANNOUNCEMENT}
    else:
        output = decide(payload.get("tool_input") or {})
    if output:
        print(json.dumps({"hookSpecificOutput": output}))
    return 0


if __name__ == "__main__":
    sys.exit(main())

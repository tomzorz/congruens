"""Run each hook script the way Claude Code does: JSON on stdin, a real process.

python -m unittest discover -s agents/config/hooks
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

HERE = Path(__file__).parent


def run_hook(script: str, payload: dict[str, Any], env: dict[str, str] | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, str(HERE / script)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env={**os.environ, **(env or {})},
        check=True,
    )


def question(text: str) -> dict[str, Any]:
    return {"question": text, "header": text[:12], "multiSelect": False, "options": [{"label": "A"}, {"label": "B"}]}


class ScratchEnvTest(unittest.TestCase):
    def setUp(self) -> None:
        handle = tempfile.NamedTemporaryFile("w", suffix=".sh", delete=False)
        handle.close()
        self.env_file = Path(handle.name)
        self.addCleanup(self.env_file.unlink)

    def test_exports_the_scratchpad(self) -> None:
        run_hook("scratch_env.py", {"scratchpad_dir": "/tmp/claude-1000/proj/abc/scratchpad"}, {"CLAUDE_ENV_FILE": str(self.env_file)})
        self.assertEqual(self.env_file.read_bytes(), b"export SCRATCH=/tmp/claude-1000/proj/abc/scratchpad\n")

    def test_tells_the_session_about_it(self) -> None:
        out = run_hook("scratch_env.py", {"scratchpad_dir": "/tmp/s"}, {"CLAUDE_ENV_FILE": str(self.env_file)}).stdout
        spec = json.loads(out)["hookSpecificOutput"]
        self.assertEqual(spec["hookEventName"], "SessionStart")
        self.assertIn("$SCRATCH", spec["additionalContext"])
        self.assertIn("/tmp/s", spec["additionalContext"])

    @unittest.skipUnless(os.name == "nt", "backslash paths only arrive on Windows")
    def test_windows_path_gets_forward_slashes(self) -> None:
        run_hook("scratch_env.py", {"scratchpad_dir": "C:\\Users\\me\\Temp\\claude\\p\\abc\\scratchpad"}, {"CLAUDE_ENV_FILE": str(self.env_file)})
        self.assertEqual(self.env_file.read_bytes(), b"export SCRATCH=C:/Users/me/Temp/claude/p/abc/scratchpad\n")

    def test_quotes_a_path_with_spaces(self) -> None:
        run_hook("scratch_env.py", {"scratchpad_dir": "/tmp/my dir/scratchpad"}, {"CLAUDE_ENV_FILE": str(self.env_file)})
        self.assertEqual(self.env_file.read_text(encoding="utf-8"), "export SCRATCH='/tmp/my dir/scratchpad'\n")

    def test_appends_to_what_other_hooks_wrote(self) -> None:
        self.env_file.write_text("export OTHER=1\n", encoding="utf-8", newline="\n")
        run_hook("scratch_env.py", {"scratchpad_dir": "/tmp/s"}, {"CLAUDE_ENV_FILE": str(self.env_file)})
        self.assertEqual(self.env_file.read_text(encoding="utf-8"), "export OTHER=1\nexport SCRATCH=/tmp/s\n")

    def test_no_scratchpad_writes_and_says_nothing(self) -> None:
        out = run_hook("scratch_env.py", {"session_id": "abc"}, {"CLAUDE_ENV_FILE": str(self.env_file)}).stdout
        self.assertEqual((self.env_file.read_bytes(), out), (b"", ""))

    def test_no_env_file_is_harmless(self) -> None:
        env = {k: v for k, v in os.environ.items() if k != "CLAUDE_ENV_FILE"}
        result = subprocess.run(
            [sys.executable, str(HERE / "scratch_env.py")],
            input=json.dumps({"scratchpad_dir": "/tmp/s"}),
            capture_output=True,
            text=True,
            env=env,
        )
        self.assertEqual((result.returncode, result.stdout), (0, ""))


class AskCatchAllTest(unittest.TestCase):
    def decide(self, questions: list[dict[str, Any]], **extra: Any) -> dict[str, Any] | None:
        payload = {"hook_event_name": "PreToolUse", "tool_name": "AskUserQuestion", "tool_input": {"questions": questions, **extra}}
        out = run_hook("ask_catch_all.py", payload).stdout
        return json.loads(out)["hookSpecificOutput"] if out.strip() else None

    def test_single_question_is_left_alone(self) -> None:
        self.assertIsNone(self.decide([question("Which one?")]))

    def test_two_questions_get_the_catch_all_with_ask(self) -> None:
        out = self.decide([question("First?"), question("Second?")])
        assert out is not None
        self.assertEqual(out["permissionDecision"], "ask")
        texts = [q["question"] for q in out["updatedInput"]["questions"]]
        self.assertEqual(texts, ["First?", "Second?", "Would you like to add anything else?"])

    def test_catch_all_is_never_pre_answered(self) -> None:
        out = self.decide([question("First?"), question("Second?")])
        assert out is not None
        self.assertNotIn("answers", out["updatedInput"])
        self.assertNotEqual(out["permissionDecision"], "allow")

    def test_three_questions_fill_the_fourth_slot(self) -> None:
        out = self.decide([question("One?"), question("Two?"), question("Three?")])
        assert out is not None
        self.assertEqual(len(out["updatedInput"]["questions"]), 4)

    def test_other_input_fields_survive(self) -> None:
        out = self.decide([question("One?"), question("Two?")], metadata={"source": "x"})
        assert out is not None
        self.assertEqual(out["updatedInput"]["metadata"], {"source": "x"})

    def test_round_that_already_has_one_is_left_alone(self) -> None:
        self.assertIsNone(self.decide([question("One?"), question("Would you like to add anything else?")]))

    def test_tailored_catch_all_counts(self) -> None:
        self.assertIsNone(self.decide([question("One?"), question("Anything else I should know first?")]))

    def test_anything_else_in_an_earlier_question_is_not_a_catch_all(self) -> None:
        out = self.decide([question("Did the 'anything else' question show up?"), question("Commit now?")])
        assert out is not None
        self.assertEqual(out["updatedInput"]["questions"][-1]["question"], "Would you like to add anything else?")

    def test_session_start_announces_the_hook(self) -> None:
        out = run_hook("ask_catch_all.py", {"hook_event_name": "SessionStart", "source": "startup"}).stdout
        spec = json.loads(out)["hookSpecificOutput"]
        self.assertEqual(spec["hookEventName"], "SessionStart")
        self.assertIn("ask at most three questions", spec["additionalContext"])

    def test_four_questions_are_denied_with_the_reason(self) -> None:
        out = self.decide([question("One?"), question("Two?"), question("Three?"), question("Four?")])
        assert out is not None
        self.assertEqual(out["permissionDecision"], "deny")
        self.assertIn("at most 3 questions", out["permissionDecisionReason"])

    def test_four_with_a_catch_all_already_pass(self) -> None:
        self.assertIsNone(self.decide([question("One?"), question("Two?"), question("Three?"), question("Anything else?")]))

    def test_missing_questions_is_left_alone(self) -> None:
        self.assertIsNone(self.decide([]))


if __name__ == "__main__":
    unittest.main()

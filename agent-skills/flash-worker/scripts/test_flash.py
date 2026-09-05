#!/usr/bin/env python3
"""Offline regression tests for flash report handling; no worker is launched."""

import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).with_name("flash.sh")


class ReportTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="flash-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.workspace = self.root / "workspace"
        self.workspace.mkdir()
        self.lane = self.root.name
        self.events = self.root / "events.jsonl"
        self.called = self.root / "called"
        fake = self.root / "agy"
        fake.write_text(
            '#!/bin/sh\n: > "$FLASH_TEST_CALLED"\n'
            'cat "$FLASH_TEST_EVENTS"\nexit "${FLASH_TEST_EXIT:-0}"\n'
        )
        fake.chmod(0o755)
        self.env = {k: v for k, v in os.environ.items() if not k.startswith("FLASH_")}
        self.env.update(
            FLASH_AGY=str(fake),
            XDG_CACHE_HOME=str(self.root / "cache"),
            FLASH_TEST_CALLED=str(self.called),
            FLASH_TEST_EVENTS=str(self.events),
        )
        self.body = "\n".join(f"line {i:03d} " + "x" * 70 for i in range(100))

    def report_path(self, workspace=None):
        key = hashlib.sha1(str(workspace or self.workspace).encode()).hexdigest()[:12]
        return self.root / "cache" / "flash" / key / f"{self.lane}.out"

    def stream(self, body=None, status="SUCCESS", partial=None, crash=False):
        events = [{"event": "init", "conversation_id": "test-conversation"}]
        if partial is not None:
            events.append({"event": "step_update", "step_update": {"text_delta": partial}})
        if not crash:
            events.append({"event": "result", "result": {
                "status": status, "response": self.body if body is None else body,
            }})
        self.events.write_text("\n".join(map(json.dumps, events)) + "\n")

    def run_flash(self, *options, workspace=None, stdout=subprocess.PIPE):
        return subprocess.run(
            [str(SCRIPT), "-d", str(workspace or self.workspace), "-n", self.lane,
             *options, "test task"],
            env=self.env, text=True, stdout=stdout, stderr=subprocess.PIPE, timeout=10,
        )

    def assert_capped(self, text, body, limit=2):
        self.assertEqual(text.splitlines()[:limit], body.splitlines()[:limit])
        self.assertEqual(len(text.splitlines()), limit + 2)
        self.assertIn(str(self.report_path()), text)

    def test_success_caps_stdout_but_saves_full_report(self):
        self.stream()
        result = self.run_flash("--spill", "2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_capped(result.stdout, self.body)
        self.assertEqual(self.report_path().read_text(), self.body + "\n")

    def test_unlimited_and_short_reports_have_no_notice(self):
        for body, options in [(self.body, ()), (self.body, ("--spill", "0")),
                              ("one\ntwo", ("--spill", "2"))]:
            with self.subTest(options=options, lines=len(body.splitlines())):
                self.stream(body)
                result = self.run_flash(*options)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, body + "\n")

    def test_caller_redirect_does_not_alias_saved_report(self):
        capture = Path("/tmp/flash") / f"{self.lane}.out"
        capture.parent.mkdir(exist_ok=True)
        self.addCleanup(capture.unlink, missing_ok=True)
        self.stream()
        with capture.open("w") as output:
            result = self.run_flash("--spill", "2", stdout=output)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_capped(capture.read_text(), self.body)
        self.assertEqual(self.report_path().read_text(), self.body + "\n")

    def test_workspaces_keep_separate_reports_and_leave_tmp_alone(self):
        mirror = Path("/tmp/flash") / f"{self.lane}.out"
        mirror.parent.mkdir(exist_ok=True)
        self.addCleanup(mirror.unlink, missing_ok=True)
        mirror.write_text("caller-owned capture")
        other = self.root / "other workspace"
        other.mkdir()
        for workspace, body in [(self.workspace, "workspace A"), (other, "workspace B")]:
            self.stream(body)
            result = self.run_flash(workspace=workspace)
            self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.report_path().read_text(), "workspace A\n")
        self.assertEqual(self.report_path(other).read_text(), "workspace B\n")
        self.assertEqual(mirror.read_text(), "caller-owned capture")

    def test_crash_replaces_stale_report_and_caps_partial_output(self):
        self.stream("previous report")
        self.assertEqual(self.run_flash().returncode, 0)
        self.stream(partial=self.body, crash=True)
        self.env["FLASH_TEST_EXIT"] = "9"
        result = self.run_flash("--spill", "2")
        self.assertEqual(result.returncode, 3, result.stderr)
        self.assert_capped(result.stdout, self.body)
        self.assertEqual(self.report_path().read_text(), self.body + "\n")

    def test_error_response_and_stream_fallback_are_saved_and_capped(self):
        for body, partial in [(self.body, None), ("", self.body)]:
            with self.subTest(fallback=partial is not None):
                self.stream(body, status="ERROR", partial=partial)
                result = self.run_flash("--spill", "2")
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assert_capped(result.stdout, self.body)
                self.assertEqual(self.report_path().read_text(), self.body + "\n")

    def test_empty_success_and_empty_crash_keep_failure_exit_codes(self):
        for crash, code in [(False, 2), (True, 3)]:
            with self.subTest(crash=crash):
                self.stream("", crash=crash)
                result = self.run_flash("--spill", "2")
                self.assertEqual(result.returncode, code, result.stderr)
                self.assertEqual(self.report_path().read_text().strip(), "")

    def test_invalid_caps_fail_before_worker_launch(self):
        for value in ["", "oops", "-1", "1.5", "2x", "9" * 40]:
            for source in ["flag", "env"]:
                with self.subTest(value=value, source=source):
                    self.env.pop("FLASH_SPILL_LINES", None)
                    options = ("--spill", value)
                    if source == "env":
                        self.env["FLASH_SPILL_LINES"] = value
                        options = ()
                    result = self.run_flash(*options)
                    self.assertEqual(result.returncode, 64, result.stderr)
                    self.assertFalse(self.called.exists())

    def test_environment_default_and_flag_override(self):
        self.stream()
        self.env["FLASH_SPILL_LINES"] = "2"
        result = self.run_flash()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_capped(result.stdout, self.body)
        self.env["FLASH_SPILL_LINES"] = "invalid"
        result = self.run_flash("--spill", "0")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, self.body + "\n")


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Offline regression tests for external-worker launcher."""

import hashlib
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest


LAUNCHER = Path(__file__).with_name("external-worker.sh")


class ExternalWorkerTestBase(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="ew-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.workspace = self.root / "workspace"
        self.workspace.mkdir()

        self.bin_dir = self.root / "bin"
        self.bin_dir.mkdir()

        self.invocations_file = self.root / "invocations.jsonl"
        self.events_file = self.root / "events.jsonl"
        self.called_file = self.root / "called"

        # Create universal fake CLI
        fake_cli_code = """#!/usr/bin/env python3
import json
import os
from pathlib import Path
import sys
import time

log_path = os.environ.get("EW_TEST_INVOCATIONS")
if log_path:
    record = {
        "bin": os.path.basename(sys.argv[0]),
        "argv": sys.argv[1:],
        "cwd": os.getcwd(),
    }
    with open(log_path, "a") as f:
        f.write(json.dumps(record) + "\\n")

called = os.environ.get("EW_TEST_CALLED")
if called:
    Path(called).touch()

events_file = os.environ.get("EW_TEST_EVENTS")
if events_file and os.path.exists(events_file):
    with open(events_file, "r") as f:
        for line in f:
            sys.stdout.write(line)
            sys.stdout.flush()

sleep_time = float(os.environ.get("EW_TEST_SLEEP", "0"))
if sleep_time > 0:
    time.sleep(sleep_time)

if os.environ.get("EW_TEST_HANG") == "1":
    while True:
        time.sleep(0.1)

exit_code = int(os.environ.get("EW_TEST_EXIT_CODE", "0"))
sys.exit(exit_code)
"""
        for bin_name in ("fake_agy", "fake_claude", "fake_agent"):
            p = self.bin_dir / bin_name
            p.write_text(fake_cli_code)
            p.chmod(0o755)

        self.env = {k: v for k, v in os.environ.items() if not k.startswith("EW_") and not k.startswith("FLASH_") and not k.startswith("CW_") and not k.startswith("CRW_")}
        self.env.update({
            "EW_GEMINI_BIN": str(self.bin_dir / "fake_agy"),
            "EW_CLAUDE_BIN": str(self.bin_dir / "fake_claude"),
            "EW_CURSOR_BIN": str(self.bin_dir / "fake_agent"),
            "XDG_CACHE_HOME": str(self.root / "cache"),
            "EW_TEST_INVOCATIONS": str(self.invocations_file),
            "EW_TEST_EVENTS": str(self.events_file),
            "EW_TEST_CALLED": str(self.called_file),
            "PATH": f"{self.bin_dir}:{os.environ.get('PATH', '')}",
        })
        self.body = "\n".join(f"line {i:03d} " + "x" * 60 for i in range(100))

    def get_invocations(self):
        if not self.invocations_file.exists():
            return []
        lines = self.invocations_file.read_text().splitlines()
        return [json.loads(line) for line in lines if line.strip()]

    def report_path(self, executor="gemini", workspace=None):
        ws = str(workspace or self.workspace)
        key = hashlib.sha1(ws.encode()).hexdigest()[:12]
        return self.root / "cache" / "external-worker" / key / executor / "report.out"

    def state_dir(self, executor="gemini", workspace=None):
        ws = str(workspace or self.workspace)
        key = hashlib.sha1(ws.encode()).hexdigest()[:12]
        return self.root / "cache" / "external-worker" / key / executor

    def write_stream(self, executor="gemini", body=None, status="SUCCESS", partial=None, crash=False, session_id="test-session"):
        events = []
        if executor == "gemini":
            events.append({"event": "init", "conversation_id": session_id})
            if partial is not None:
                events.append({"event": "step_update", "step_update": {
                    "state": "ACTIVE", "step_type": "tool", "tool_name": "read", "text_delta": partial
                }})
            if not crash:
                events.append({"event": "result", "result": {
                    "status": status,
                    "response": self.body if body is None else body,
                    "error": "simulated failure" if status != "SUCCESS" else None,
                }})
        elif executor == "claude":
            if partial is not None:
                events.append({
                    "type": "assistant",
                    "message": {"content": [{"type": "text", "text": partial}]}
                })
            if not crash:
                is_err = (status != "SUCCESS")
                events.append({
                    "type": "result",
                    "subtype": "success" if not is_err else "error",
                    "is_error": is_err,
                    "result": self.body if body is None else body,
                })
        elif executor == "cursor":
            events.append({"type": "system", "subtype": "init", "session_id": session_id})
            if partial is not None:
                events.append({
                    "type": "assistant",
                    "message": {"content": [{"type": "text", "text": partial}]}
                })
            if not crash:
                is_err = (status != "SUCCESS")
                events.append({
                    "type": "result",
                    "subtype": "success" if not is_err else "error",
                    "is_error": is_err,
                    "result": self.body if body is None else body,
                })

        self.events_file.write_text("\n".join(json.dumps(e) for e in events) + "\n")

    def run_cmd(self, *args, workspace=None, env_extra=None, stdin=None, timeout=10, stdout=subprocess.PIPE):
        env = dict(self.env)
        if env_extra:
            env.update(env_extra)
        cmd = [str(LAUNCHER)]
        if workspace is not False:
            cmd.extend(["-d", str(workspace or self.workspace)])
        cmd.extend(args)

        is_text = (stdout == subprocess.PIPE)
        stdin_data = stdin
        if is_text and isinstance(stdin_data, bytes):
            stdin_data = stdin_data.decode()
        elif not is_text and isinstance(stdin_data, str):
            stdin_data = stdin_data.encode()

        return subprocess.run(
            cmd,
            env=env,
            input=stdin_data,
            stdout=stdout,
            stderr=subprocess.PIPE,
            text=is_text,
            timeout=timeout,
        )

    def assert_capped(self, text, body, executor="gemini", limit=2):
        lines = text.splitlines()
        expected = body.splitlines()[:limit]
        self.assertEqual(lines[:limit], expected)
        self.assertEqual(len(lines), limit + 2)
        notice = f"[external-worker: report capped at {limit} lines. Full report: {self.report_path(executor)}]"
        self.assertIn(notice, text)


class OptionParsingTests(ExternalWorkerTestBase):
    def test_default_workspace_uses_current_directory(self):
        self.write_stream(body="done")
        result = subprocess.run([str(LAUNCHER.resolve()), "task"], cwd=self.workspace,
                                env=self.env, capture_output=True, text=True, timeout=10)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.get_invocations()[0]["cwd"], str(self.workspace))

    def test_environment_cap_and_flag_override(self):
        self.write_stream()
        result = self.run_cmd("task", env_extra={"EW_SPILL_LINES": "2"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assert_capped(result.stdout, self.body)
        result = self.run_cmd("--spill", "0", "task", env_extra={"EW_SPILL_LINES": "invalid"})
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout, self.body + "\n")

    def test_default_executor_is_gemini(self):
        self.write_stream("gemini", body="gemini response")
        res = self.run_cmd("sample task")
        self.assertEqual(res.returncode, 0, res.stderr)
        invs = self.get_invocations()
        self.assertEqual(len(invs), 1)
        self.assertEqual(invs[0]["bin"], "fake_agy")
        argv = invs[0]["argv"]
        self.assertIn("--model", argv)
        self.assertIn("gemini-3.8-flash", argv)
        self.assertIn("--effort", argv)
        self.assertIn("high", argv)
        self.assertIn("--add-dir", argv)
        self.assertIn(str(self.workspace), argv)
        self.assertIn("--dangerously-skip-permissions", argv)

    def test_explicit_executors(self):
        cases = [
            ("gemini", "-e", "fake_agy"),
            ("gemini", "--executor", "fake_agy"),
            ("claude", "-e", "fake_claude"),
            ("claude", "--executor", "fake_claude"),
            ("cursor", "-e", "fake_agent"),
            ("cursor", "--executor", "fake_agent"),
        ]
        for executor, flag, expected_bin in cases:
            with self.subTest(executor=executor, flag=flag):
                self.invocations_file.unlink(missing_ok=True)
                self.write_stream(executor, body=f"{executor} output")
                res = self.run_cmd(flag, executor, f"task for {executor}")
                self.assertEqual(res.returncode, 0, res.stderr)
                invs = self.get_invocations()
                self.assertEqual(len(invs), 1)
                self.assertEqual(invs[0]["bin"], expected_bin)

    def test_invalid_executor_fails_early(self):
        for invalid in ["unknown", "gpt-4", "deepseek", ""]:
            with self.subTest(invalid=invalid):
                res = self.run_cmd("-e", invalid, "task")
                self.assertEqual(res.returncode, 64)
                self.assertIn("unknown executor", res.stderr)
                self.assertFalse(self.called_file.exists())

    def test_lane_flags_rejected_early(self):
        for lane_flag in ["-n", "--lane"]:
            with self.subTest(lane_flag=lane_flag):
                res = self.run_cmd(lane_flag, "custom_lane", "task")
                self.assertEqual(res.returncode, 64)
                self.assertIn("lanes are not supported", res.stderr)
                self.assertFalse(self.called_file.exists())

    def test_contradictory_actions_fail_early(self):
        combos = [
            ("-c", "-p"),
            ("-p", "-k"),
            ("-k", "--selftest"),
            ("-c", "--selftest"),
            ("-p", "-c"),
        ]
        for a1, a2 in combos:
            with self.subTest(a1=a1, a2=a2):
                res = self.run_cmd(a1, a2, "task")
                self.assertEqual(res.returncode, 64)
                self.assertIn("contradictory", res.stderr)
                self.assertFalse(self.called_file.exists())

    def test_invalid_spill_caps_fail_early(self):
        for value in ["", "oops", "-1", "1.5", "2x", "9" * 40]:
            for source in ["flag", "env"]:
                with self.subTest(value=value, source=source):
                    self.called_file.unlink(missing_ok=True)
                    options = ["--spill", value] if source == "flag" else []
                    env_extra = {"EW_SPILL_LINES": value} if source == "env" else {}
                    res = self.run_cmd(*options, "task", env_extra=env_extra)
                    self.assertEqual(res.returncode, 64, res.stderr)
                    self.assertFalse(self.called_file.exists())

    def test_missing_and_empty_task(self):
        # Empty task argument
        res = self.run_cmd("   \n\t  ")
        self.assertEqual(res.returncode, 64)
        self.assertIn("task is empty", res.stderr)


class ArgumentIntegrityTests(ExternalWorkerTestBase):
    def test_arbitrary_task_text_preserved(self):
        weird_task = """Arbitrary: $PATH `uname -a` $(rm -rf /) * ? [a-z] "quotes" 'single' \t and \n newlines"""
        self.write_stream("gemini", body="done")
        res = self.run_cmd(weird_task)
        self.assertEqual(res.returncode, 0, res.stderr)
        invs = self.get_invocations()
        self.assertEqual(len(invs), 1)
        argv = invs[0]["argv"]
        p_idx = argv.index("-p")
        self.assertEqual(argv[p_idx + 1], weird_task)

    def test_spaces_in_workspace_path(self):
        spaced_ws = self.root / "path with spaces and 'quotes'"
        spaced_ws.mkdir()
        self.write_stream("cursor", body="done")
        res = self.run_cmd("-e", "cursor", "task", workspace=spaced_ws)
        self.assertEqual(res.returncode, 0, res.stderr)
        invs = self.get_invocations()
        self.assertEqual(len(invs), 1)
        self.assertEqual(invs[0]["cwd"], str(spaced_ws.resolve()))
        argv = invs[0]["argv"]
        ws_idx = argv.index("--workspace")
        self.assertEqual(argv[ws_idx + 1], str(spaced_ws.resolve()))

    def test_stdin_task_packet(self):
        stdin_content = "multi-line\npacket from stdin\nwith $VARS and ; symbols"
        self.write_stream("claude", body="done")
        res = self.run_cmd("-e", "claude", stdin=stdin_content)
        self.assertEqual(res.returncode, 0, res.stderr)
        invs = self.get_invocations()
        self.assertEqual(len(invs), 1)
        argv = invs[0]["argv"]
        p_idx = argv.index("-p")
        self.assertEqual(argv[p_idx + 1], stdin_content)

    def test_double_dash_hyphen_task(self):
        self.write_stream("gemini", body="done")
        res = self.run_cmd("--", "-hyphen-flag-task")
        self.assertEqual(res.returncode, 0, res.stderr)
        invs = self.get_invocations()
        self.assertEqual(len(invs), 1)
        argv = invs[0]["argv"]
        p_idx = argv.index("-p")
        self.assertEqual(argv[p_idx + 1], "-hyphen-flag-task")


class ProviderArgvTests(ExternalWorkerTestBase):
    def test_gemini_read_only_and_write_argv(self):
        # Read-only Gemini: needs BOTH --mode plan AND --dangerously-skip-permissions
        self.write_stream("gemini", body="ok")
        res = self.run_cmd("-e", "gemini", "-r", "task ro")
        self.assertEqual(res.returncode, 0, res.stderr)
        argv = self.get_invocations()[0]["argv"]
        self.assertIn("--mode", argv)
        self.assertEqual(argv[argv.index("--mode") + 1], "plan")
        self.assertIn("--dangerously-skip-permissions", argv)

        # Write Gemini: no --mode plan
        self.invocations_file.unlink()
        self.write_stream("gemini", body="ok")
        res = self.run_cmd("-e", "gemini", "task rw")
        self.assertEqual(res.returncode, 0, res.stderr)
        argv = self.get_invocations()[0]["argv"]
        self.assertNotIn("--mode", argv)
        self.assertIn("--dangerously-skip-permissions", argv)

    def test_claude_read_only_and_write_argv(self):
        # Read-only Claude: --permission-mode plan ALONE, NEVER --dangerously-skip-permissions
        self.write_stream("claude", body="ok")
        res = self.run_cmd("-e", "claude", "-r", "task ro")
        self.assertEqual(res.returncode, 0, res.stderr)
        argv = self.get_invocations()[0]["argv"]
        self.assertIn("--permission-mode", argv)
        self.assertEqual(argv[argv.index("--permission-mode") + 1], "plan")
        self.assertNotIn("--dangerously-skip-permissions", argv)

        # Write Claude: --dangerously-skip-permissions, NEVER --permission-mode plan
        self.invocations_file.unlink()
        self.write_stream("claude", body="ok")
        res = self.run_cmd("-e", "claude", "task rw")
        self.assertEqual(res.returncode, 0, res.stderr)
        argv = self.get_invocations()[0]["argv"]
        self.assertIn("--dangerously-skip-permissions", argv)
        self.assertNotIn("--permission-mode", argv)

    def test_claude_budget_option(self):
        self.write_stream("claude", body="ok")
        res = self.run_cmd("-e", "claude", "task", env_extra={"EW_CLAUDE_BUDGET": "7.5"})
        self.assertEqual(res.returncode, 0, res.stderr)
        argv = self.get_invocations()[0]["argv"]
        self.assertIn("--max-budget-usd", argv)
        self.assertEqual(argv[argv.index("--max-budget-usd") + 1], "7.5")

    def test_cursor_read_only_and_write_argv(self):
        # Read-only Cursor: ask mode and force; plan permits switching to write mode
        self.write_stream("cursor", body="ok")
        res = self.run_cmd("-e", "cursor", "-r", "task ro")
        self.assertEqual(res.returncode, 0, res.stderr)
        argv = self.get_invocations()[0]["argv"]
        self.assertEqual(argv[argv.index("--mode") + 1], "ask")
        self.assertIn("--force", argv)

        # Write Cursor: force with no read-only mode
        self.invocations_file.unlink()
        self.write_stream("cursor", body="ok")
        res = self.run_cmd("-e", "cursor", "task rw")
        self.assertEqual(res.returncode, 0, res.stderr)
        argv = self.get_invocations()[0]["argv"]
        self.assertIn("--force", argv)
        self.assertNotIn("--mode", argv)

    def test_continuation_flags_and_session_inheritance(self):
        # Gemini continuation
        self.write_stream("gemini", body="init", session_id="gem-session-42")
        res = self.run_cmd("-e", "gemini", "task 1")
        self.assertEqual(res.returncode, 0, res.stderr)
        self.invocations_file.unlink()
        self.write_stream("gemini", body="resumed")
        res = self.run_cmd("-e", "gemini", "-c", "task continue")
        self.assertEqual(res.returncode, 0, res.stderr)
        argv = self.get_invocations()[0]["argv"]
        self.assertIn("--conversation", argv)
        self.assertEqual(argv[argv.index("--conversation") + 1], "gem-session-42")
        self.assertNotIn("--model", argv)
        self.assertNotIn("--effort", argv)
        self.assertIn("--print-timeout", argv)

        # Claude continuation
        self.invocations_file.unlink()
        self.write_stream("claude", body="init")
        res = self.run_cmd("-e", "claude", "task 1")
        self.assertEqual(res.returncode, 0, res.stderr)
        first_argv = self.get_invocations()[0]["argv"]
        self.assertIn("--session-id", first_argv)
        sid = first_argv[first_argv.index("--session-id") + 1]

        self.invocations_file.unlink()
        self.write_stream("claude", body="resumed")
        res = self.run_cmd("-e", "claude", "-c", "task continue")
        self.assertEqual(res.returncode, 0, res.stderr)
        resume_argv = self.get_invocations()[0]["argv"]
        self.assertIn("--resume", resume_argv)
        self.assertEqual(resume_argv[resume_argv.index("--resume") + 1], sid)
        self.assertNotIn("--session-id", resume_argv)
        self.assertNotIn("--model", resume_argv)
        self.assertNotIn("--effort", resume_argv)

        # Cursor continuation
        self.invocations_file.unlink()
        self.write_stream("cursor", body="init", session_id="cur-sess-99")
        res = self.run_cmd("-e", "cursor", "task 1")
        self.assertEqual(res.returncode, 0, res.stderr)

        self.invocations_file.unlink()
        self.write_stream("cursor", body="resumed")
        res = self.run_cmd("-e", "cursor", "-c", "task continue")
        self.assertEqual(res.returncode, 0, res.stderr)
        resume_argv = self.get_invocations()[0]["argv"]
        self.assertIn("--resume", resume_argv)
        self.assertEqual(resume_argv[resume_argv.index("--resume") + 1], "cur-sess-99")
        self.assertNotIn("--model", resume_argv)

    def test_continuation_mode_inheritance_and_rejection(self):
        # Read-only run continued without -r MUST inherit read-only mode
        self.write_stream("gemini", body="first")
        res = self.run_cmd("-e", "gemini", "-r", "task ro")
        self.assertEqual(res.returncode, 0, res.stderr)

        self.invocations_file.unlink()
        self.write_stream("gemini", body="resumed")
        res = self.run_cmd("-e", "gemini", "-c", "task continue without -r")
        self.assertEqual(res.returncode, 0, res.stderr)
        argv = self.get_invocations()[0]["argv"]
        # Must still have read-only flag --mode plan!
        self.assertIn("--mode", argv)
        self.assertEqual(argv[argv.index("--mode") + 1], "plan")

        # Write run continued with -r MUST be rejected
        other_ws = self.root / "ws_write"
        other_ws.mkdir()
        self.write_stream("claude", body="first")
        res = self.run_cmd("-e", "claude", "task write", workspace=other_ws)
        self.assertEqual(res.returncode, 0, res.stderr)

        res = self.run_cmd("-e", "claude", "-c", "-r", "task continue with -r", workspace=other_ws)
        self.assertEqual(res.returncode, 64)
        self.assertIn("cannot continue a write session in read-only mode", res.stderr)


class ReportHandlingAndExitCodeTests(ExternalWorkerTestBase):
    def test_failures_replace_old_reports_and_cap_partial_output(self):
        for executor in ["gemini", "claude", "cursor"]:
            for crash, code in [(False, 1), (True, 3)]:
                with self.subTest(executor=executor, crash=crash):
                    self.write_stream(executor, body="old report")
                    self.assertEqual(self.run_cmd("-e", executor, "first").returncode, 0)
                    self.write_stream(executor, body="", status="ERROR", partial=self.body,
                                      crash=crash)
                    result = self.run_cmd("-e", executor, "--spill", "2", "second")
                    self.assertEqual(result.returncode, code, result.stderr)
                    self.assert_capped(result.stdout, self.body, executor=executor)
                    self.assertEqual(self.report_path(executor).read_text(), self.body + "\n")

    def test_all_executors_capping_and_full_report(self):
        for executor in ["gemini", "claude", "cursor"]:
            with self.subTest(executor=executor):
                self.write_stream(executor, body=self.body)
                res = self.run_cmd("-e", executor, "--spill", "2", "task")
                self.assertEqual(res.returncode, 0, res.stderr)
                self.assert_capped(res.stdout, self.body, executor=executor, limit=2)
                self.assertEqual(self.report_path(executor).read_text(), self.body + "\n")

    def test_uncapped_and_short_reports(self):
        for body, spill in [(self.body, "0"), ("short\nreport", "5")]:
            with self.subTest(lines=len(body.splitlines()), spill=spill):
                self.write_stream("gemini", body=body)
                res = self.run_cmd("-e", "gemini", "--spill", spill, "task")
                self.assertEqual(res.returncode, 0, res.stderr)
                self.assertEqual(res.stdout, body + "\n")
                self.assertNotIn("report capped at", res.stdout)

    def test_caller_redirect_does_not_alias_saved_report(self):
        capture = self.root / "caller_capture.out"
        self.write_stream("claude", body=self.body)
        with capture.open("w") as out:
            res = self.run_cmd("-e", "claude", "--spill", "2", "task", stdout=out)
        self.assertEqual(res.returncode, 0)
        self.assert_capped(capture.read_text(), self.body, executor="claude", limit=2)
        self.assertEqual(self.report_path("claude").read_text(), self.body + "\n")

    def test_empty_success_returns_exit_2(self):
        for executor in ["gemini", "claude", "cursor"]:
            for empty_body in ["", "   \n\t  \n"]:
                with self.subTest(executor=executor, empty_body=repr(empty_body)):
                    self.write_stream(executor, body=empty_body)
                    res = self.run_cmd("-e", executor, "task")
                    self.assertEqual(res.returncode, 2, res.stderr)
                    self.assertEqual(self.report_path(executor).read_text().strip(), "")

    def test_provider_error_returns_exit_1_and_salvages_output(self):
        for executor in ["gemini", "claude", "cursor"]:
            with self.subTest(executor=executor):
                partial_text = "partial salvage before error\n"
                self.write_stream(executor, body="", status="ERROR", partial=partial_text)
                res = self.run_cmd("-e", executor, "task")
                self.assertEqual(res.returncode, 1, res.stderr)
                self.assertIn("partial salvage before error", res.stdout)
                self.assertEqual(self.report_path(executor).read_text().strip(), "partial salvage before error")

    def test_nonzero_cli_exit_with_result_returns_exit_1(self):
        # CLI exit nonzero must be treated as error even if result payload claimed success
        self.write_stream("gemini", body="result with error exit")
        res = self.run_cmd("-e", "gemini", "task", env_extra={"EW_TEST_EXIT_CODE": "5"})
        self.assertEqual(res.returncode, 1, res.stderr)
        self.assertIn("result with error exit", res.stdout)

    def test_crash_returns_exit_3_and_salvages_partial(self):
        for executor in ["gemini", "claude", "cursor"]:
            with self.subTest(executor=executor):
                partial_text = "salvaged chunk 1\nsalvaged chunk 2\n"
                self.write_stream(executor, partial=partial_text, crash=True)
                res = self.run_cmd("-e", executor, "task", env_extra={"EW_TEST_EXIT_CODE": "9"})
                self.assertEqual(res.returncode, 3, res.stderr)
                self.assertIn("salvaged chunk 1", res.stdout)
                self.assertEqual(self.report_path(executor).read_text().strip(), partial_text.strip())


class IsolationAndConcurrencyTests(ExternalWorkerTestBase):
    def test_delayed_lock_publication_cannot_be_stolen(self):
        mkdir = self.bin_dir / "mkdir"
        mkdir.write_text('#!/bin/bash\n/bin/mkdir "$@"\nrc=$?\n'
                         'if [ "$rc" = 0 ] && [[ "$1" = */lock ]]; then sleep 0.5; fi\n'
                         'exit "$rc"\n')
        mkdir.chmod(0o755)
        self.write_stream(body="only one run")
        first = subprocess.Popen([str(LAUNCHER), "-d", str(self.workspace), "first"],
                                 env={**self.env, "EW_TEST_SLEEP": "1"},
                                 stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 5
            while not (self.state_dir() / "lock").exists():
                self.assertLess(time.monotonic(), deadline)
                time.sleep(0.01)
            second = self.run_cmd("second")
            self.assertEqual(second.returncode, 1, second.stderr)
            _, errors = first.communicate(timeout=5)
            self.assertEqual(first.returncode, 0, errors)
            self.assertEqual(len(self.get_invocations()), 1)
        finally:
            if first.poll() is None:
                first.terminate()
                first.communicate(timeout=5)

    def test_symlinked_workspace_uses_same_state(self):
        alias = self.root / "workspace-alias"
        alias.symlink_to(self.workspace, target_is_directory=True)
        self.write_stream(body="canonical report")
        result = self.run_cmd("task", workspace=alias)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.report_path().read_text(), "canonical report\n")

    def test_isolation_across_executors_in_same_workspace(self):
        self.write_stream("gemini", body="gemini report")
        res1 = self.run_cmd("-e", "gemini", "task 1")
        self.assertEqual(res1.returncode, 0)

        self.write_stream("claude", body="claude report")
        res2 = self.run_cmd("-e", "claude", "task 2")
        self.assertEqual(res2.returncode, 0)

        self.assertEqual(self.report_path("gemini").read_text().strip(), "gemini report")
        self.assertEqual(self.report_path("claude").read_text().strip(), "claude report")

    def test_isolation_across_workspaces_for_same_executor(self):
        other_ws = self.root / "ws_other"
        other_ws.mkdir()

        self.write_stream("cursor", body="report A")
        res1 = self.run_cmd("-e", "cursor", "task A", workspace=self.workspace)
        self.assertEqual(res1.returncode, 0)

        self.write_stream("cursor", body="report B")
        res2 = self.run_cmd("-e", "cursor", "task B", workspace=other_ws)
        self.assertEqual(res2.returncode, 0)

        self.assertEqual(self.report_path("cursor", self.workspace).read_text().strip(), "report A")
        self.assertEqual(self.report_path("cursor", other_ws).read_text().strip(), "report B")

    def test_simultaneous_starts_atomic_exclusion(self):
        # Start worker 1 that sleeps
        self.write_stream("gemini", body="first report")
        env_hang = dict(self.env)
        env_hang["EW_TEST_SLEEP"] = "1.5"

        p1 = subprocess.Popen(
            [str(LAUNCHER), "-e", "gemini", "-d", str(self.workspace), "task sleep"],
            env=env_hang, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )

        # Give p1 a moment to acquire lock
        time.sleep(0.2)

        # Start worker 2 for same (workspace, executor)
        p2 = subprocess.run(
            [str(LAUNCHER), "-e", "gemini", "-d", str(self.workspace), "task rejected"],
            env=self.env, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )

        # p2 must fail with exit code 1 immediately
        self.assertEqual(p2.returncode, 1)
        self.assertIn("already running", p2.stderr)

        p1_out, p1_err = p1.communicate(timeout=5)
        self.assertEqual(p1.returncode, 0, p1_err)

    def test_rejected_start_does_not_corrupt_existing_report_or_session(self):
        # Complete run 1
        self.write_stream("gemini", body="initial valid report", session_id="initial-sess-1")
        res1 = self.run_cmd("-e", "gemini", "task 1")
        self.assertEqual(res1.returncode, 0)
        sess_file = self.state_dir("gemini") / "id"
        self.assertEqual(sess_file.read_text().strip(), "initial-sess-1")

        # Start background run that holds lock
        self.write_stream("gemini", body="new report")
        p_active = subprocess.Popen(
            [str(LAUNCHER), "-e", "gemini", "-d", str(self.workspace), "active task"],
            env={**self.env, "EW_TEST_SLEEP": "1.0"},
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        time.sleep(0.2)

        # Rejected attempt
        p_rej = self.run_cmd("-e", "gemini", "rejected task")
        self.assertEqual(p_rej.returncode, 1)

        p_active.communicate(timeout=5)


class ResumeGuaranteesTests(ExternalWorkerTestBase):
    def test_all_providers_inherit_read_only_and_reject_missing_mode(self):
        for executor, flag in [("gemini", "--mode"), ("claude", "--permission-mode"),
                               ("cursor", "--mode")]:
            with self.subTest(executor=executor):
                self.write_stream(executor, body="done")
                self.assertEqual(self.run_cmd("-e", executor, "-r", "task").returncode, 0)
                self.assertEqual(self.run_cmd("-e", executor, "-c", "correct").returncode, 0)
                argv = self.get_invocations()[-1]["argv"]
                self.assertIn(flag, argv)
                if executor == "claude":
                    self.assertNotIn("--dangerously-skip-permissions", argv)
                (self.state_dir(executor) / "mode").unlink()
                count = len(self.get_invocations())
                result = self.run_cmd("-e", executor, "-c", "correct")
                self.assertEqual(result.returncode, 1, result.stderr)
                self.assertEqual(len(self.get_invocations()), count)

    def test_resume_without_prior_session_fails(self):
        res = self.run_cmd("-e", "gemini", "-c", "resume task")
        self.assertEqual(res.returncode, 1)
        self.assertIn("no previous worker", res.stderr)

    def test_resume_never_targets_another_executor(self):
        # Run claude
        self.write_stream("claude", body="claude report")
        res = self.run_cmd("-e", "claude", "task claude")
        self.assertEqual(res.returncode, 0)

        # Try resuming gemini in the same workspace
        res_gemini = self.run_cmd("-e", "gemini", "-c", "resume gemini")
        self.assertEqual(res_gemini.returncode, 1)
        self.assertIn("no previous worker for executor 'gemini'", res_gemini.stderr)

    def test_failed_new_launch_clears_old_session(self):
        # Run 1 succeeds
        self.write_stream("gemini", body="first report", session_id="first-sess-id")
        res1 = self.run_cmd("-e", "gemini", "task 1")
        self.assertEqual(res1.returncode, 0)
        self.assertTrue((self.state_dir("gemini") / "id").exists())

        # Run 2 starts fresh but crashes with no events
        self.events_file.unlink(missing_ok=True)
        res2 = self.run_cmd("-e", "gemini", "task 2", env_extra={"EW_TEST_EXIT_CODE": "1"})
        self.assertEqual(res2.returncode, 3)

        # Old session id must have been cleared!
        self.assertFalse((self.state_dir("gemini") / "id").exists())

        # Resume must fail cleanly, not target stale first-sess-id
        res3 = self.run_cmd("-e", "gemini", "-c", "task 3 resume")
        self.assertEqual(res3.returncode, 1)
        self.assertIn("no previous worker", res3.stderr)


class LifecyclePeekKillTests(ExternalWorkerTestBase):
    def test_peek_and_kill_without_provider_binaries(self):
        self.write_stream("gemini", body="report text")
        self.run_cmd("-e", "gemini", "run task")

        # Break provider binary
        broken_env = dict(self.env)
        broken_env["EW_GEMINI_BIN"] = "/nonexistent/path/agy"

        # Peek still succeeds without binary
        res_peek = self.run_cmd("-e", "gemini", "-p", env_extra=broken_env)
        self.assertEqual(res_peek.returncode, 0, res_peek.stderr)
        self.assertIn("status: finished", res_peek.stdout)

        # Kill without running worker exits 1 without needing binary
        res_kill = self.run_cmd("-e", "gemini", "-k", env_extra=broken_env)
        self.assertEqual(res_kill.returncode, 1, res_kill.stderr)
        self.assertIn("no running worker", res_kill.stderr)

    def test_peek_shows_running_and_previous_report(self):
        # Previous finished report
        self.write_stream("gemini", body="previous report text")
        self.run_cmd("-e", "gemini", "first task")

        # Start active worker
        self.write_stream("gemini", partial="partial stream progress\n")
        p_active = subprocess.Popen(
            [str(LAUNCHER), "-e", "gemini", "-d", str(self.workspace), "active task"],
            env={**self.env, "EW_TEST_HANG": "1"},
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        time.sleep(0.3)

        res_peek = self.run_cmd("-e", "gemini", "-p")
        self.assertEqual(res_peek.returncode, 0, res_peek.stderr)
        self.assertIn("status: RUNNING", res_peek.stdout)
        self.assertIn("previous report:", res_peek.stdout)
        self.assertIn("output so far:", res_peek.stdout)

        # Kill active worker
        self.run_cmd("-e", "gemini", "-k")
        p_active.communicate(timeout=5)

    def test_kill_running_worker_exits_0_and_runner_exits_1_with_salvaged_output(self):
        self.write_stream("cursor", partial="partial cursor work\n")
        p_active = subprocess.Popen(
            [str(LAUNCHER), "-e", "cursor", "-d", str(self.workspace), "long task"],
            env={**self.env, "EW_TEST_HANG": "1"},
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        time.sleep(0.3)

        # Execute kill
        res_kill = self.run_cmd("-e", "cursor", "-k")
        self.assertEqual(res_kill.returncode, 0, res_kill.stderr)
        self.assertIn("killed cursor", res_kill.stderr)

        # Runner must salvage partial output and exit 1
        stdout, stderr = p_active.communicate(timeout=5)
        self.assertEqual(p_active.returncode, 1)
        self.assertIn("partial cursor work", stdout)
        self.assertEqual(self.report_path("cursor").read_text().strip(), "partial cursor work")

    def test_stale_lock_is_retained_for_explicit_recovery(self):
        # Manually create stale lock directory with dead PID
        lockdir = self.state_dir("gemini") / "lock"
        lockdir.mkdir(parents=True, exist_ok=True)
        (lockdir / "wrapper.pid").write_text("9999999\n")
        (lockdir / "wrapper.lstart").write_text("Sat Sep  5 00:00:00 2026\n")

        self.write_stream("gemini", body="recovered from stale lock")
        res = self.run_cmd("-e", "gemini", "task after stale")
        self.assertEqual(res.returncode, 1, res.stderr)
        self.assertTrue(lockdir.exists())
        self.assertFalse(self.called_file.exists())

    def test_stale_pid_recycling_protection(self):
        # Set wrapper.pid to PID 1 (launchd, which is alive), but with mismatched lstart
        lockdir = self.state_dir("claude") / "lock"
        lockdir.mkdir(parents=True, exist_ok=True)
        (lockdir / "wrapper.pid").write_text("1\n")
        (lockdir / "wrapper.lstart").write_text("Bogus timestamp 1970\n")

        self.write_stream("claude", body="ran successfully despite recycled pid")
        res = self.run_cmd("-e", "claude", "task recycled")
        self.assertEqual(res.returncode, 1, res.stderr)
        killed = self.run_cmd("-e", "claude", "-k")
        self.assertEqual(killed.returncode, 1)
        self.assertTrue(lockdir.exists())
        self.assertFalse(self.called_file.exists())

    def test_lock_cleanup_only_releases_own_lock(self):
        # Process A holds lock
        self.write_stream("gemini", body="report A")
        p1 = subprocess.Popen(
            [str(LAUNCHER), "-e", "gemini", "-d", str(self.workspace), "task A"],
            env={**self.env, "EW_TEST_SLEEP": "1.0"},
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        time.sleep(0.2)

        lockdir = self.state_dir("gemini") / "lock"
        self.assertTrue(lockdir.exists())

        # Process B starts and is rejected
        p2 = self.run_cmd("-e", "gemini", "task B")
        self.assertEqual(p2.returncode, 1)

        # Process B's exit must NOT have removed Process A's lock
        self.assertTrue(lockdir.exists())
        self.assertEqual((lockdir / "wrapper.pid").read_text().strip(), str(p1.pid))

        p1.communicate(timeout=5)


if __name__ == "__main__":
    unittest.main()

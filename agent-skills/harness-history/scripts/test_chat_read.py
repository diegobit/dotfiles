#!/usr/bin/env python3
"""Offline regression tests for chat-read.sh. Fixture stores only; never the live dbs."""

from __future__ import annotations

import json
import os
import shutil
import sqlite3
import subprocess
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("chat-read.sh")
EXACT_ID = "f37457a9-c7e8-4a1a-92c8-eebff42211db"
ASTRA_ID = "astra-0000-0000-0000-000000000001"
CURSOR_ID = "cursor-0000-0000-0000-000000000002"
CONTINUE_ID = "8541e616-0df1-4657-bcf3-36b9ab535c30"
HIDDEN_ID = "id-prefix-w0910-should-not-list"
APOSTROPHE_ID = "apo-0000-0000-0000-000000000003"
TWIN1_ID = "twin-0000-0000-0000-000000000001"
TWIN2_ID = "twin-0000-0000-0000-000000000002"
REGEX_ID = "regex-0000-0000-0000-000000000001"
DELETED_ID = "deleted-w0910-0000-000000000001"
OC_ID = "oc-session-w0910-0001"
FIRST_MARKER = "FIRST-MSG-MUST-NOT-APPEAR-IN-LAST"
EXACT_MARKER = "EXACT-W0910-BODY"
ASTRA_MARKER = "ASTRA-BODY"
CURSOR_MARKER = "CURSOR-BODY"
CONTINUE_MARKER = "CONTINUE-BODY"
COMMIT_USER = "Commit se devi…"
APOSTROPHE_TITLE = "Diego's notes"
APOSTROPHE_MARKER = "APOSTROPHE-BODY"


def _insert_thread(con: sqlite3.Connection, thread_id: str, title: str, updated: str,
                   deleted: str | None = None, branch: str = "main") -> None:
    con.execute(
        """
        INSERT INTO projection_threads
            (thread_id, project_id, title, branch, created_at, updated_at, deleted_at)
        VALUES (?, 'proj', ?, ?, ?, ?, ?)
        """,
        (thread_id, title, branch, updated, updated, deleted),
    )


def _insert_msg(con: sqlite3.Connection, message_id: str, thread_id: str, role: str,
                text: str, created: str) -> None:
    con.execute(
        """
        INSERT INTO projection_thread_messages
            (message_id, thread_id, role, text, created_at, updated_at)
        VALUES (?, ?, ?, ?, ?, ?)
        """,
        (message_id, thread_id, role, text, created, created),
    )


def build_t3_db(path: Path, *, include_exact: bool = True) -> None:
    if path.exists():
        path.unlink()
    con = sqlite3.connect(path)
    con.executescript(
        """
        CREATE TABLE projection_threads (
            thread_id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            title TEXT NOT NULL,
            branch TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            deleted_at TEXT
        );
        CREATE TABLE projection_thread_messages (
            message_id TEXT PRIMARY KEY,
            thread_id TEXT NOT NULL,
            role TEXT NOT NULL,
            text TEXT NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
        );
        """
    )
    exact_title = "w0910" if include_exact else "w0910-renamed"
    _insert_thread(con, EXACT_ID, exact_title, "2026-09-16T12:00:00Z")
    _insert_thread(con, ASTRA_ID, "w0910 astra", "2026-09-16T11:00:00Z")
    _insert_thread(con, CURSOR_ID, "w0910 cursor", "2026-09-16T10:00:00Z")
    _insert_thread(con, CONTINUE_ID, "Continue Work from w0910", "2026-09-16T13:00:00Z")
    _insert_thread(con, HIDDEN_ID, "quiet night", "2026-09-16T09:00:00Z")
    _insert_thread(con, APOSTROPHE_ID, APOSTROPHE_TITLE, "2026-09-15T08:00:00Z")
    _insert_thread(con, TWIN1_ID, "twin", "2026-09-14T08:00:00Z")
    _insert_thread(con, TWIN2_ID, "twin", "2026-09-14T07:00:00Z")
    _insert_thread(con, REGEX_ID, "fooXbar", "2026-09-13T08:00:00Z")
    _insert_thread(con, DELETED_ID, "w0910", "2026-09-12T08:00:00Z", deleted="2026-09-12T09:00:00Z")

    # 84 messages on the exact-title thread: marker at 0, user at 75, eight assistants after.
    for i in range(84):
        created = f"2026-09-01T00:{i:02d}:00Z"
        if i == 0:
            role, text = "user", FIRST_MARKER
        elif i == 1:
            role, text = "assistant", EXACT_MARKER
        elif i == 75:
            role, text = "user", COMMIT_USER
        elif i >= 76:
            role, text = "assistant", f"assistant-tail-{i}"
        else:
            role = "assistant" if i % 2 else "user"
            text = f"filler-{i}"
        _insert_msg(con, f"exact-msg-{i:03d}", EXACT_ID, role, text, created)

    _insert_msg(con, "astra-1", ASTRA_ID, "user", ASTRA_MARKER, "2026-09-16T11:00:01Z")
    _insert_msg(con, "cursor-1", CURSOR_ID, "user", CURSOR_MARKER, "2026-09-16T10:00:01Z")
    _insert_msg(con, "cont-1", CONTINUE_ID, "user", CONTINUE_MARKER, "2026-09-16T13:00:01Z")
    _insert_msg(con, "apo-1", APOSTROPHE_ID, "user", APOSTROPHE_MARKER, "2026-09-15T08:00:01Z")
    _insert_msg(con, "twin1-1", TWIN1_ID, "user", "TWIN1-BODY", "2026-09-14T08:00:01Z")
    _insert_msg(con, "twin2-1", TWIN2_ID, "user", "TWIN2-BODY", "2026-09-14T07:00:01Z")
    con.commit()
    con.close()


def build_oc_db(path: Path) -> None:
    if path.exists():
        path.unlink()
    con = sqlite3.connect(path)
    con.executescript(
        """
        CREATE TABLE project (
            id TEXT PRIMARY KEY,
            worktree TEXT NOT NULL
        );
        CREATE TABLE session (
            id TEXT PRIMARY KEY,
            project_id TEXT NOT NULL,
            title TEXT NOT NULL,
            time_created INTEGER NOT NULL,
            time_archived INTEGER,
            agent TEXT
        );
        CREATE TABLE message (
            id TEXT PRIMARY KEY,
            session_id TEXT NOT NULL,
            time_created INTEGER NOT NULL,
            data TEXT NOT NULL
        );
        CREATE TABLE part (
            id TEXT PRIMARY KEY,
            message_id TEXT NOT NULL,
            session_id TEXT NOT NULL,
            time_created INTEGER NOT NULL,
            data TEXT NOT NULL
        );
        """
    )
    con.execute("INSERT INTO project (id, worktree) VALUES ('p1', '/tmp/oc-work')")
    con.execute(
        "INSERT INTO session (id, project_id, title, time_created, time_archived, agent) "
        "VALUES (?, 'p1', 'w0910', 1700000000000, NULL, 'build')"
        , (OC_ID,),
    )
    # Three messages; last is user with two parts so N counts messages, not parts.
    msgs = [
        ("m1", "user", 1700000000000, [("p1", "text", {"type": "text", "text": "OC-FIRST"})]),
        ("m2", "assistant", 1700000001000, [
            ("p2a", "text", {"type": "text", "text": "OC-ASSIST"}),
            ("p2b", "tool", {"type": "tool", "tool": "shell", "state": {"input": "ls", "output": "ok"}}),
        ]),
        ("m3", "user", 1700000002000, [("p3", "text", {"type": "text", "text": "OC-LAST-USER"})]),
    ]
    for mid, role, ts, parts in msgs:
        con.execute(
            "INSERT INTO message (id, session_id, time_created, data) VALUES (?, ?, ?, ?)",
            (mid, OC_ID, ts, json.dumps({"role": role})),
        )
        for pid, _ptype, payload in parts:
            con.execute(
                "INSERT INTO part (id, message_id, session_id, time_created, data) VALUES (?, ?, ?, ?, ?)",
                (pid, mid, OC_ID, ts, json.dumps(payload)),
            )
    con.commit()
    con.close()


def build_claude_store(root: Path) -> None:
    proj = root / "proj"
    proj.mkdir(parents=True)
    exact = proj / "claude-w0910.jsonl"
    cousin = proj / "claude-w0910-astra.jsonl"
    lines_exact = [
        json.dumps({"type": "ai-title", "sessionId": "claude-w0910", "aiTitle": "w0910"}),
        json.dumps({"type": "user", "message": {"role": "user", "content": "CLAUDE-FIRST"}}),
    ]
    for i in range(8):
        lines_exact.append(json.dumps({
            "type": "assistant",
            "message": {"role": "assistant", "content": f"claude-tail-{i}"},
        }))
    exact.write_text("\n".join(lines_exact) + "\n")
    cousin.write_text(
        json.dumps({"type": "ai-title", "sessionId": "claude-w0910-astra", "aiTitle": "w0910 astra"})
        + "\n"
        + json.dumps({"type": "user", "message": {"role": "user", "content": "CLAUDE-ASTRA"}})
        + "\n"
    )


class ChatReadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.temp = tempfile.TemporaryDirectory(prefix="chat-read-test-")
        root = Path(cls.temp.name)
        cls.db = root / "t3.sqlite"
        cls.db_no_exact = root / "t3-no-exact.sqlite"
        cls.oc_db = root / "oc.sqlite"
        cls.claude_root = root / "claude"
        cls.codex_root = root / "codex"
        cls.anti_root = root / "anti"
        cls.codex_root.mkdir()
        cls.anti_root.mkdir()
        build_t3_db(cls.db, include_exact=True)
        build_t3_db(cls.db_no_exact, include_exact=False)
        build_oc_db(cls.oc_db)
        build_claude_store(cls.claude_root)

    @classmethod
    def tearDownClass(cls) -> None:
        cls.temp.cleanup()

    def run_cmd(self, *args: str, db: Path | None = None, extra_env: dict[str, str] | None = None
                ) -> subprocess.CompletedProcess[str]:
        env = os.environ.copy()
        env["T3_DB"] = str(db or self.db)
        env["OC_DB"] = str(self.oc_db)
        env["CLAUDE_ROOT"] = str(self.claude_root)
        env["CODEX_ROOT"] = str(self.codex_root)
        env["ANTI_ROOT"] = str(self.anti_root)
        env["ANTI_CLI_ROOT"] = str(self.anti_root)
        if extra_env:
            env.update(extra_env)
        return subprocess.run(
            ["bash", str(SCRIPT), *args],
            capture_output=True,
            text=True,
            env=env,
        )

    def test_list_w0910_returns_search_rows_not_id_hits(self) -> None:
        proc = self.run_cmd("list", "t3", "w0910")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        ids = [line.split("\t", 1)[0] for line in proc.stdout.splitlines() if line]
        self.assertEqual(set(ids), {EXACT_ID, ASTRA_ID, CURSOR_ID, CONTINUE_ID})
        self.assertNotIn(HIDDEN_ID, ids)
        self.assertNotIn(DELETED_ID, ids)
        self.assertGreaterEqual(len(ids), 2)

    def test_list_does_not_regex_match(self) -> None:
        proc = self.run_cmd("list", "t3", "foo.bar")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertEqual(proc.stdout.strip(), "")

    def test_get_exact_unique_title(self) -> None:
        proc = self.run_cmd("get", "t3", "w0910")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn(EXACT_MARKER, proc.stdout)
        self.assertIn(FIRST_MARKER, proc.stdout)
        self.assertNotIn(ASTRA_MARKER, proc.stdout)
        self.assertNotIn(CURSOR_MARKER, proc.stdout)
        self.assertRegex(proc.stdout, r"\[2026-09-01T00:")

    def test_get_ambiguous_without_exact_title(self) -> None:
        proc = self.run_cmd("get", "t3", "w0910", db=self.db_no_exact)
        self.assertEqual(proc.returncode, 1)
        self.assertIn("Found", proc.stderr)
        self.assertIn("w0910 astra", proc.stderr)
        self.assertIn("w0910 cursor", proc.stderr)
        self.assertNotIn(EXACT_MARKER, proc.stdout)

    def test_get_id_wins(self) -> None:
        proc = self.run_cmd("get", "t3", ASTRA_ID)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn(ASTRA_MARKER, proc.stdout)
        self.assertNotIn(EXACT_MARKER, proc.stdout)

    def test_get_apostrophe_title(self) -> None:
        proc = self.run_cmd("get", "t3", APOSTROPHE_TITLE)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn(APOSTROPHE_MARKER, proc.stdout)

    def test_get_sql_injection_query_does_not_drop_tables(self) -> None:
        proc = self.run_cmd("get", "t3", "x'; DROP TABLE projection_threads; --")
        self.assertEqual(proc.returncode, 1)
        listed = self.run_cmd("list", "t3", "w0910")
        self.assertEqual(listed.returncode, 0, listed.stderr)
        self.assertIn(EXACT_ID, listed.stdout)

    def test_duplicate_exact_title_is_ambiguous(self) -> None:
        proc = self.run_cmd("get", "t3", "twin")
        self.assertEqual(proc.returncode, 1)
        self.assertIn("Found 2 chats", proc.stderr)

    def test_missing_db_is_not_empty_success(self) -> None:
        missing = Path(self.temp.name) / "no-such.sqlite"
        proc = self.run_cmd("list", "t3", extra_env={"T3_DB": str(missing)})
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(proc.stderr.strip())
        self.assertEqual(proc.stdout.strip(), "")

    def test_corrupt_db_is_not_empty_success(self) -> None:
        bad = Path(self.temp.name) / "corrupt.sqlite"
        bad.write_text("not a database\n")
        proc = self.run_cmd("list", "t3", extra_env={"T3_DB": str(bad)})
        self.assertNotEqual(proc.returncode, 0)
        self.assertTrue(proc.stderr.strip())

    def test_last_expands_past_assistant_only_window(self) -> None:
        proc = self.run_cmd("last", "t3", EXACT_ID, "8")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn(COMMIT_USER, proc.stdout)
        self.assertNotIn(FIRST_MARKER, proc.stdout)
        self.assertRegex(proc.stdout, r"\[2026-09-01T00:")
        self.assertIn("[user]", proc.stdout)
        assistant_tails = [line for line in proc.stdout.splitlines() if "assistant-tail-" in line]
        self.assertEqual(len(assistant_tails), 8)

    def test_last_exact_title_does_not_dump_full_thread(self) -> None:
        proc = self.run_cmd("last", "t3", "w0910")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn(COMMIT_USER, proc.stdout)
        self.assertNotIn(FIRST_MARKER, proc.stdout)
        self.assertLess(len(proc.stdout.splitlines()), 84)

    def test_last_ambiguous_exits_1(self) -> None:
        proc = self.run_cmd("last", "t3", "w0910", db=self.db_no_exact)
        self.assertEqual(proc.returncode, 1)
        self.assertIn("Found", proc.stderr)

    def test_skill_contract(self) -> None:
        skill = Path(__file__).resolve().parents[1] / "SKILL.md"
        text = skill.read_text()
        self.assertNotIn("project_threads", text)
        self.assertNotIn("projection_threads", text)
        self.assertNotIn("projection_thread_messages", text)
        self.assertNotIn("/Users/diego/.t3", text)
        self.assertNotIn("`raw/`", text)
        self.assertNotIn("raw/", text)
        self.assertIn("resume or continue", text.split("---", 2)[1])
        self.assertIn("## Resume", text)
        self.assertIn("git status", text)
        self.assertIn("tool", text.lower())
        self.assertIn("compaction", text)
        self.assertNotIn("id | date | title/workspace | project", text)

    def test_opencode_get_and_last(self) -> None:
        got = self.run_cmd("get", "opencode", "w0910")
        self.assertEqual(got.returncode, 0, got.stderr)
        self.assertIn("OC-FIRST", got.stdout)
        self.assertIn("OC-LAST-USER", got.stdout)
        self.assertIn("## tool shell", got.stdout)
        last = self.run_cmd("last", "opencode", "w0910", "1")
        self.assertEqual(last.returncode, 0, last.stderr)
        self.assertIn("OC-LAST-USER", last.stdout)
        self.assertNotIn("OC-FIRST", last.stdout)

    def test_claude_exact_title_and_last(self) -> None:
        if shutil.which("jq") is None:
            self.skipTest("jq not installed")
        got = self.run_cmd("get", "claude", "w0910")
        self.assertEqual(got.returncode, 0, got.stderr)
        self.assertIn("CLAUDE-FIRST", got.stdout)
        self.assertNotIn("CLAUDE-ASTRA", got.stdout)
        last = self.run_cmd("last", "claude", "w0910", "8")
        self.assertEqual(last.returncode, 0, last.stderr)
        self.assertIn("CLAUDE-FIRST", last.stdout)
        self.assertIn("[user]", last.stdout)


if __name__ == "__main__":
    unittest.main()

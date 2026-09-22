#!/usr/bin/env python3
"""Synthetic tests for cleanup.py. Fixtures live in a temp directory, never a live OpenCode data dir."""

from __future__ import annotations

import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import cleanup  # noqa: E402


SCRIPT = Path(__file__).with_name("cleanup.py")
NOW = 1_700_000_000
OLD = NOW - 10 * 86400
RECENT = NOW - 30
PROJECT = "a" * 40
UNKNOWN_PROJECT = "b" * 40
MS = NOW * 1000


def run(args):
    # Fixtures have no OpenCode writers. Live apply must confirm this explicitly.
    if args and args[0] == "apply":
        args = [*args, "--offline"]
    return subprocess.run(
        [sys.executable, str(SCRIPT), *args],
        capture_output=True,
        text=True,
    )


class Fixture:
    def __init__(self) -> None:
        self._tmp = tempfile.TemporaryDirectory()
        self.root = Path(self._tmp.name)
        self.data = self.root / "data"
        self.data.mkdir()
        self.manifest = self.root / "manifest.json"
        self.outside = self.root / "outside.txt"
        self.outside.write_text("keep-me")

    def close(self) -> None:
        self._tmp.cleanup()

    def write(self, rel, content=b"x", mtime=OLD):
        path = self.data / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content if isinstance(content, bytes) else content.encode())
        os.utime(path, (mtime, mtime))
        return path

    def snapshot(self, project, mtime=OLD):
        head = self.write("snapshot/%s/HEAD" % project, b"ref: refs/heads/master\n", mtime)
        objects = head.parent / "objects"
        objects.mkdir(exist_ok=True)
        os.utime(objects, (mtime, mtime))
        os.utime(head.parent, (mtime, mtime))
        return head.parent

    def db(self, sessions, projects=None, messages=None, extra_session_sql=""):
        if projects is None:
            projects = [(PROJECT,)]
        path = self.data / "opencode.db"
        conn = sqlite3.connect(path)
        conn.execute(
            "CREATE TABLE project (id text PRIMARY KEY, worktree text NOT NULL,"
            " time_created integer NOT NULL, time_updated integer NOT NULL)"
        )
        conn.execute(
            "CREATE TABLE session (id text PRIMARY KEY, project_id text NOT NULL,"
            " time_created integer NOT NULL, time_updated integer NOT NULL,"
            " time_archived integer%s)" % extra_session_sql
        )
        conn.execute(
            "CREATE TABLE message (id text PRIMARY KEY, session_id text NOT NULL,"
            " time_created integer NOT NULL, time_updated integer NOT NULL, data text NOT NULL)"
        )
        for (pid,) in projects:
            conn.execute(
                "INSERT INTO project VALUES (?,?,?,?)",
                (pid, "/tmp/work", MS, MS),
            )
        for sid, pid, updated in sessions:
            conn.execute(
                "INSERT INTO session (id, project_id, time_created, time_updated) VALUES (?,?,?,?)",
                (sid, pid, MS, updated),
            )
        if messages:
            for mid, sid in messages:
                conn.execute(
                    "INSERT INTO message VALUES (?,?,?,?,?)",
                    (mid, sid, MS, MS, "{}"),
                )
        conn.commit()
        conn.close()

    def paths(self):
        found = []
        for dirpath, dirnames, filenames in os.walk(self.data):
            dirnames[:] = [name for name in dirnames]
            for name in filenames:
                found.append(os.path.relpath(os.path.join(dirpath, name), self.data))
        return sorted(found)


class CleanupTests(unittest.TestCase):
    def setUp(self):
        self.fx = Fixture()
        self.fx.db(
            sessions=[("ses_keep", PROJECT, MS)],
            messages=[("msg_keep", "ses_keep")],
        )
        self.fx.write("storage/session_diff/ses_keep.json", b"keep")
        self.fx.write("storage/session_diff/ses_gone.json", b"gone")
        self.fx.write("storage/session_diff/notes.json", b"notes")
        self.fx.write("storage/session_diff/session.json", b"not-an-id")
        self.fx.write("storage/message/ses_keep/msg_keep.json", b"m")
        self.fx.write("storage/message/ses_gone/msg_old.json", b"old-m")
        self.fx.write("storage/part/msg_keep/prt_keep.json", b"p")
        self.fx.write("storage/part/msg_gone/prt_old.json", b"op")
        self.fx.write("storage/part/ses_keep/prt_wrong.json", b"wrong-layout")
        self.fx.write("storage/session/%s/ses_keep.json" % PROJECT, b"s")
        self.fx.write("storage/session/%s/ses_gone.json" % PROJECT, b"sg")
        self.fx.write("storage/migration", b"2")
        self.fx.write("storage/project/%s.json" % PROJECT, b"proj")
        self.fx.write("auth.json", b"secret")
        self.fx.snapshot(PROJECT)
        self.fx.snapshot(UNKNOWN_PROJECT)
        self.fx.write("snapshot/notes/README", b"nope")
        self.fx.write("log/opencode.log", b"recent-log", RECENT)
        self.fx.write("log/old.log", b"old-log", OLD)
        for dirpath, dirnames, _filenames in os.walk(self.fx.data):
            os.utime(dirpath, (OLD, OLD))
            for name in dirnames:
                os.utime(os.path.join(dirpath, name), (OLD, OLD))

    def tearDown(self):
        self.fx.close()

    def preview(self, *extra):
        return run(
            [
                "preview",
                "--data-dir",
                str(self.fx.data),
                "--manifest",
                str(self.fx.manifest),
                "--protect-mtime-seconds",
                "3600",
                "--now",
                str(NOW),
                *extra,
            ]
        )

    def test_missing_session_referenced_by_message_refuses(self):
        conn = sqlite3.connect(self.fx.data / "opencode.db")
        conn.execute("UPDATE message SET session_id = 'ses_gone'")
        conn.commit()
        conn.close()
        result = self.preview()
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn("missing session", result.stderr)
        self.assertFalse(self.fx.manifest.exists())
        self.assertTrue((self.fx.data / "storage/message/ses_gone/msg_old.json").exists())

    def test_manifest_symlink_in_data_directory_refuses(self):
        link = self.fx.data / "manifest-link.json"
        link.symlink_to(self.fx.outside)
        before = self.fx.outside.read_bytes()
        self.fx.manifest = link
        result = self.preview()
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertTrue(link.is_symlink())
        self.assertEqual(self.fx.outside.read_bytes(), before)

    def test_manifest_cannot_overwrite_database_or_storage(self):
        db = self.fx.data / "opencode.db"
        before = db.read_bytes()
        self.fx.manifest = db
        result = self.preview()
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn("outside", result.stderr)
        self.assertEqual(db.read_bytes(), before)

    def test_symlinked_storage_root_is_refused(self):
        storage = self.fx.data / "storage"
        moved = self.fx.root / "moved-storage"
        storage.rename(moved)
        storage.symlink_to(moved, target_is_directory=True)
        result = self.preview()
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn("symlink", result.stderr)
        self.assertTrue((moved / "session_diff/ses_gone.json").exists())

    def test_apply_requires_offline_confirmation(self):
        result = subprocess.run(
            [sys.executable, str(SCRIPT), "apply", "--manifest", str(self.fx.manifest),
             "--expect", "0" * 64], capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        self.assertIn("offline", result.stderr)

    def test_invalid_timestamp_types_refuse(self):
        for value in (0, -1, "not-a-timestamp", 1700000000000.5):
            with self.subTest(value=value):
                conn = sqlite3.connect(self.fx.data / "opencode.db")
                conn.execute("UPDATE session SET time_updated = ?", (value,))
                conn.commit()
                conn.close()
                result = self.preview()
                self.assertEqual(result.returncode, 2, result.stdout)
                self.assertFalse(self.fx.manifest.exists())

    def test_preview_does_not_mutate_and_selects_orphans(self):
        before = self.fx.paths()
        result = self.preview("--session-retention-days", "1")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.fx.paths(), before)
        summary = json.loads(result.stdout)
        self.assertFalse(summary["approved"])
        manifest = json.loads(self.fx.manifest.read_text())
        self.assertFalse(manifest["approved"])
        rels = [item["relpath"] for item in manifest["candidates"]]
        self.assertIn("storage/session_diff/ses_gone.json", rels)
        self.assertIn("storage/message/ses_gone", rels)
        self.assertIn("storage/part/msg_gone", rels)
        self.assertIn("storage/session/%s/ses_gone.json" % PROJECT, rels)
        self.assertIn("snapshot/%s" % UNKNOWN_PROJECT, rels)
        for kept in (
            "storage/session_diff/ses_keep.json",
            "storage/session_diff/notes.json",
            "storage/session_diff/session.json",
            "storage/message/ses_keep",
            "storage/part/msg_keep",
            "storage/part/ses_keep",
            "storage/session/%s/ses_keep.json" % PROJECT,
            "snapshot/%s" % PROJECT,
            "snapshot/notes",
            "storage/migration",
            "auth.json",
            "log/old.log",
        ):
            self.assertNotIn(kept, rels)
        self.assertGreater(manifest["retained_counts"].get("known session", 0), 0)
        self.assertGreater(manifest["retained_counts"].get("unsupported layout", 0), 0)
        self.assertGreater(manifest["retained_counts"].get("known project", 0), 0)
        self.assertEqual(summary["fingerprint"], manifest["fingerprint"])

    def test_failed_database_read_refuses_without_deleting(self):
        db = self.fx.data / "opencode.db"
        db.write_text("id\nses_keep\n")
        before = self.fx.paths()
        result = self.preview()
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn("database", result.stderr)
        self.assertFalse(self.fx.manifest.exists())
        self.assertEqual(self.fx.paths(), before)

    def test_missing_database_refuses(self):
        (self.fx.data / "opencode.db").unlink()
        result = self.preview()
        self.assertEqual(result.returncode, 2)
        self.assertFalse(self.fx.manifest.exists())

    def test_missing_timestamp_column_refuses(self):
        path = self.fx.data / "opencode.db"
        path.unlink()
        conn = sqlite3.connect(path)
        conn.execute("CREATE TABLE project (id text PRIMARY KEY)")
        conn.execute("CREATE TABLE session (id text PRIMARY KEY, project_id text)")
        conn.execute("INSERT INTO project VALUES ('global')")
        conn.execute("INSERT INTO session VALUES ('ses_keep','global')")
        conn.commit()
        conn.close()
        result = self.preview()
        self.assertEqual(result.returncode, 2)
        self.assertIn("time_created", result.stderr)
        self.assertFalse(self.fx.manifest.exists())

    def test_unsafe_session_id_refuses(self):
        path = self.fx.data / "opencode.db"
        conn = sqlite3.connect(path)
        conn.execute(
            "INSERT INTO session (id, project_id, time_created, time_updated) VALUES (?,?,?,?)",
            ("../ses_evil", PROJECT, MS, MS),
        )
        conn.commit()
        conn.close()
        result = self.preview()
        self.assertEqual(result.returncode, 2)
        self.assertIn("unsafe", result.stderr)

    def test_non_millisecond_timestamp_refuses(self):
        path = self.fx.data / "opencode.db"
        conn = sqlite3.connect(path)
        conn.execute("UPDATE session SET time_updated = ? WHERE id = ?", (NOW, "ses_keep"))
        conn.commit()
        conn.close()
        result = self.preview()
        self.assertEqual(result.returncode, 2)
        self.assertIn("milliseconds", result.stderr)

    def test_empty_session_table_refuses_orphan_wipe(self):
        path = self.fx.data / "opencode.db"
        conn = sqlite3.connect(path)
        conn.execute("DELETE FROM message")
        conn.execute("DELETE FROM session")
        conn.commit()
        conn.close()
        result = self.preview()
        self.assertEqual(result.returncode, 2)
        self.assertIn("session table is empty", result.stderr)
        self.assertTrue((self.fx.data / "storage/session_diff/ses_keep.json").exists())
        allowed = self.preview("--allow-empty-sessions")
        self.assertEqual(allowed.returncode, 0, allowed.stderr)
        manifest = json.loads(self.fx.manifest.read_text())
        rels = [item["relpath"] for item in manifest["candidates"]]
        self.assertIn("storage/session_diff/ses_gone.json", rels)
        self.assertIn("storage/session_diff/ses_keep.json", rels)

    def test_recent_mtime_is_retained(self):
        self.fx.write("storage/session_diff/ses_fresh.json", b"fresh", RECENT)
        result = self.preview()
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads(self.fx.manifest.read_text())
        rels = [item["relpath"] for item in manifest["candidates"]]
        self.assertNotIn("storage/session_diff/ses_fresh.json", rels)
        self.assertGreater(manifest["retained_counts"].get("concurrent mtime", 0), 0)

    def test_empty_message_table_does_not_orphan_parts(self):
        path = self.fx.data / "opencode.db"
        conn = sqlite3.connect(path)
        conn.execute("DELETE FROM message")
        conn.commit()
        conn.close()
        result = self.preview()
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads(self.fx.manifest.read_text())
        rels = [item["relpath"] for item in manifest["candidates"]]
        self.assertNotIn("storage/part/msg_gone", rels)
        self.assertNotIn("storage/part/msg_keep", rels)
        self.assertIn("storage/session_diff/ses_gone.json", rels)

    def test_extra_columns_are_accepted(self):
        path = self.fx.data / "opencode.db"
        path.unlink()
        conn = sqlite3.connect(path)
        conn.execute(
            "CREATE TABLE project (id text PRIMARY KEY, worktree text, icon_url text,"
            " time_created integer, time_updated integer)"
        )
        conn.execute(
            "CREATE TABLE session (id text PRIMARY KEY, project_id text, workspace_id text,"
            " time_created integer, time_updated integer, metadata text)"
        )
        conn.execute(
            "CREATE TABLE message (id text PRIMARY KEY, session_id text, time_created integer,"
            " time_updated integer, data text)"
        )
        conn.execute("INSERT INTO project VALUES (?,?,?,?,?)", (PROJECT, "/", None, MS, MS))
        conn.execute(
            "INSERT INTO session VALUES (?,?,?,?,?,?)",
            ("ses_keep", PROJECT, None, MS, MS, None),
        )
        conn.execute("INSERT INTO message VALUES (?,?,?,?,?)", ("msg_keep", "ses_keep", MS, MS, "{}"))
        conn.commit()
        conn.close()
        result = self.preview()
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_apply_requires_approval_and_expect(self):
        preview = self.preview()
        self.assertEqual(preview.returncode, 0, preview.stderr)
        token = json.loads(preview.stdout)["fingerprint"]
        early = run(["apply", "--manifest", str(self.fx.manifest), "--expect", token, "--now", str(NOW)])
        self.assertEqual(early.returncode, 2)
        self.assertIn("not approved", early.stderr)
        self.assertTrue((self.fx.data / "storage/session_diff/ses_gone.json").exists())
        bad = run(
            ["approve", "--manifest", str(self.fx.manifest), "--expect", "0" * 64]
        )
        self.assertEqual(bad.returncode, 2)
        approved = run(["approve", "--manifest", str(self.fx.manifest), "--expect", token])
        self.assertEqual(approved.returncode, 0, approved.stderr)
        mismatch = run(
            ["apply", "--manifest", str(self.fx.manifest), "--expect", "f" * 64, "--now", str(NOW)]
        )
        self.assertEqual(mismatch.returncode, 2)
        self.assertTrue((self.fx.data / "storage/session_diff/ses_gone.json").exists())

    def test_apply_deletes_only_reviewed_candidates(self):
        preview = self.preview("--log-retention-days", "1")
        self.assertEqual(preview.returncode, 0, preview.stderr)
        token = json.loads(preview.stdout)["fingerprint"]
        manifest = json.loads(self.fx.manifest.read_text())
        rels = [item["relpath"] for item in manifest["candidates"]]
        self.assertIn("log/old.log", rels)
        self.assertNotIn("log/opencode.log", rels)
        self.assertEqual(run(["approve", "--manifest", str(self.fx.manifest), "--expect", token]).returncode, 0)
        applied = run(["apply", "--manifest", str(self.fx.manifest), "--expect", token, "--now", str(NOW)])
        self.assertEqual(applied.returncode, 0, applied.stderr)
        body = json.loads(applied.stdout)
        self.assertEqual(body["deleted_count"], len(rels))
        for rel in rels:
            self.assertFalse((self.fx.data / rel).exists(), rel)
        for rel in (
            "storage/session_diff/ses_keep.json",
            "storage/session_diff/notes.json",
            "storage/message/ses_keep/msg_keep.json",
            "storage/part/msg_keep/prt_keep.json",
            "storage/part/ses_keep/prt_wrong.json",
            "storage/session/%s/ses_keep.json" % PROJECT,
            "snapshot/%s/HEAD" % PROJECT,
            "snapshot/notes/README",
            "storage/migration",
            "storage/project/%s.json" % PROJECT,
            "auth.json",
            "log/opencode.log",
            "opencode.db",
        ):
            self.assertTrue((self.fx.data / rel).exists(), rel)
        self.assertTrue(self.fx.outside.exists())

    def test_stale_manifest_deletes_nothing(self):
        preview = self.preview()
        token = json.loads(preview.stdout)["fingerprint"]
        self.assertEqual(run(["approve", "--manifest", str(self.fx.manifest), "--expect", token]).returncode, 0)
        target = self.fx.data / "storage/session_diff/ses_gone.json"
        target.write_bytes(b"changed-after-review")
        applied = run(["apply", "--manifest", str(self.fx.manifest), "--expect", token, "--now", str(NOW)])
        self.assertEqual(applied.returncode, 2, applied.stdout)
        self.assertIn("stale", applied.stderr)
        self.assertEqual(target.read_bytes(), b"changed-after-review")
        self.assertTrue((self.fx.data / "storage/session_diff/ses_keep.json").exists())
        self.assertTrue((self.fx.data / "snapshot" / UNKNOWN_PROJECT / "HEAD").exists())

    def test_retargeted_manifest_does_not_delete_retained_file(self):
        preview = self.preview()
        self.assertEqual(preview.returncode, 0, preview.stderr)
        manifest = json.loads(self.fx.manifest.read_text())
        manifest["candidates"] = [
            {
                "relpath": "storage/session_diff/ses_keep.json",
                "kind": "file",
                "reason": "session id not in session table",
                "bytes": 4,
                "mtime_ns": 1,
                "inode": 1,
                "tree_fingerprint": "deadbeef",
            }
        ]
        manifest["approved"] = True
        payload = cleanup._payload_from_manifest(manifest)
        manifest["fingerprint"] = cleanup.fingerprint(payload)
        self.fx.manifest.write_text(json.dumps(manifest))
        applied = run(
            [
                "apply",
                "--manifest",
                str(self.fx.manifest),
                "--expect",
                manifest["fingerprint"],
                "--now",
                str(NOW),
            ]
        )
        self.assertEqual(applied.returncode, 2, applied.stdout)
        self.assertTrue((self.fx.data / "storage/session_diff/ses_keep.json").exists())
        self.assertTrue((self.fx.data / "storage/session_diff/ses_gone.json").exists())

    def test_manifest_path_escape_is_rejected(self):
        self.assertRaises(cleanup.CleanupError, cleanup._inside, str(self.fx.data), "../outside.txt")
        self.assertTrue(self.fx.outside.exists())

    def test_symlink_and_hardlink_are_not_removed(self):
        link = self.fx.data / "storage/session_diff/ses_link.json"
        link.symlink_to(self.fx.outside)
        real = self.fx.write("storage/session_diff/ses_hard.json", b"hard")
        other = self.fx.root / "hard-peer"
        os.link(real, other)
        result = self.preview()
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads(self.fx.manifest.read_text())
        rels = [item["relpath"] for item in manifest["candidates"]]
        self.assertNotIn("storage/session_diff/ses_link.json", rels)
        self.assertNotIn("storage/session_diff/ses_hard.json", rels)
        token = manifest["fingerprint"]
        self.assertEqual(run(["approve", "--manifest", str(self.fx.manifest), "--expect", token]).returncode, 0)
        applied = run(["apply", "--manifest", str(self.fx.manifest), "--expect", token, "--now", str(NOW)])
        self.assertEqual(applied.returncode, 0, applied.stderr)
        self.assertTrue(link.is_symlink())
        self.assertEqual(self.fx.outside.read_text(), "keep-me")
        self.assertEqual(other.read_bytes(), b"hard")
        self.assertTrue(real.exists())

    def test_known_project_snapshot_survives_when_it_has_no_extra_sessions(self):
        result = self.preview()
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads(self.fx.manifest.read_text())
        rels = [item["relpath"] for item in manifest["candidates"]]
        self.assertNotIn("snapshot/%s" % PROJECT, rels)
        self.assertNotIn("snapshot/global", rels)
        self.assertIn("snapshot/%s" % UNKNOWN_PROJECT, rels)

    def test_session_age_review_is_not_deleted(self):
        path = self.fx.data / "opencode.db"
        conn = sqlite3.connect(path)
        old_ms = (NOW - 90 * 86400) * 1000
        conn.execute(
            "INSERT INTO session (id, project_id, time_created, time_updated) VALUES (?,?,?,?)",
            ("ses_old", PROJECT, old_ms, old_ms),
        )
        conn.commit()
        conn.close()
        self.fx.write("storage/session_diff/ses_old.json", b"still-here")
        result = self.preview("--session-retention-days", "30")
        self.assertEqual(result.returncode, 0, result.stderr)
        manifest = json.loads(self.fx.manifest.read_text())
        self.assertIn("ses_old", manifest["session_age_review"])
        self.assertNotIn("ses_keep", manifest["session_age_review"])
        rels = [item["relpath"] for item in manifest["candidates"]]
        self.assertNotIn("storage/session_diff/ses_old.json", rels)

    def test_nested_unknown_snapshot_is_a_candidate_and_mixed_file_is_not(self):
        nested = UNKNOWN_PROJECT
        tree = self.fx.data / "snapshot" / nested
        shutil.rmtree(tree)
        tree.mkdir()
        work = tree / "abc123"
        (work / "objects").mkdir(parents=True)
        head = work / "HEAD"
        head.write_text("ref: refs/heads/master\n")
        os.utime(head, (OLD, OLD))
        os.utime(work / "objects", (OLD, OLD))
        os.utime(work, (OLD, OLD))
        os.utime(tree, (OLD, OLD))
        result = self.preview()
        self.assertEqual(result.returncode, 0, result.stderr)
        rels = [item["relpath"] for item in json.loads(self.fx.manifest.read_text())["candidates"]]
        self.assertIn("snapshot/%s" % nested, rels)


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Fail-closed preview and apply for OpenCode on-disk storage.

Reads opencode.db itself (read-only SQLite). Never parses `opencode db` display
text. Preview writes a manifest and does not remove files. Apply removes a path
only when the manifest was approved, `--expect` matches its fingerprint, and a
fresh read still describes that same path.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sqlite3
import sys
import tempfile
import time
from typing import Dict, List, Optional, Sequence, Tuple
from urllib.parse import quote


MANIFEST_VERSION = 1
PROTECT_MTIME_SECONDS_DEFAULT = 86400

SESSION_COLUMNS = ("id", "project_id", "time_created", "time_updated")
PROJECT_COLUMNS = ("id",)
MESSAGE_COLUMNS = ("id", "session_id")

# Id factories in OpenCode 1.18.32: "ses_"+…, "msg_"+…, "prt_"+….
# Project ids are the git root commit (40 hex) or the literal "global".
SESSION_ID = re.compile(r"^ses_[A-Za-z0-9]+$")
MESSAGE_ID = re.compile(r"^msg_[A-Za-z0-9]+$")
PART_ID = re.compile(r"^prt_[A-Za-z0-9]+$")
PROJECT_SHAPE = re.compile(r"^(?:global|[0-9a-f]{40})$")
SAFE_KEY = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,200}$")
LOG_NAME = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]*\.log$")

# time_updated is Unix milliseconds (Date.now()). Values below this are seconds
# or another unit; guessing would mis-classify retention.
MIN_MS_TIMESTAMP = 100_000_000_000

SKIPPED_STORAGE = ("migration", "project", "todo", "session_share")
DB_NAMES = ("opencode.db", "opencode.db-wal", "opencode.db-shm")


class CleanupError(Exception):
    """A refusal. Nothing is deleted when this is raised before the delete loop."""


def _safe_key(value: str) -> bool:
    return isinstance(value, str) and ".." not in value and SAFE_KEY.fullmatch(value) is not None


def _require_loaded_id(kind: str, value: object) -> str:
    if not isinstance(value, str) or not _safe_key(value):
        raise CleanupError("unsafe %s id in database; refusing to decide orphans" % kind)
    return value


def _connect(db_path: str) -> sqlite3.Connection:
    if os.path.islink(db_path):
        raise CleanupError("opencode.db is a symlink; refusing to follow it")
    if not os.path.isfile(db_path):
        raise CleanupError("opencode.db is not a readable database file")
    uri = "file:%s?mode=ro" % quote(db_path, safe="/")
    try:
        conn = sqlite3.connect(uri, uri=True)
    except sqlite3.Error as exc:
        raise CleanupError("database open failed: %s" % exc) from exc
    try:
        conn.execute("PRAGMA query_only=ON")
        conn.execute("BEGIN")
        # Touch the header. A text file or truncated file fails here.
        conn.execute("SELECT count(*) FROM sqlite_master").fetchone()
    except sqlite3.Error as exc:
        conn.close()
        raise CleanupError("database read failed: %s" % exc) from exc
    return conn


def _columns(conn: sqlite3.Connection, table: str) -> Optional[List[str]]:
    try:
        rows = conn.execute("PRAGMA table_info(%s)" % table).fetchall()
    except sqlite3.Error as exc:
        raise CleanupError("schema read failed for %s: %s" % (table, exc)) from exc
    if not rows:
        return None
    return [row[1] for row in rows]


def _require_columns(present: Optional[List[str]], required: Sequence[str], table: str) -> List[str]:
    if present is None:
        raise CleanupError("required table %s is missing" % table)
    missing = [name for name in required if name not in present]
    if missing:
        raise CleanupError(
            "table %s is missing columns %s; refusing this layout" % (table, ", ".join(missing))
        )
    return present


def _load(conn: sqlite3.Connection) -> Dict[str, object]:
    session_cols = _require_columns(_columns(conn, "session"), SESSION_COLUMNS, "session")
    _require_columns(_columns(conn, "project"), PROJECT_COLUMNS, "project")
    message_cols = _columns(conn, "message")
    has_message = message_cols is not None
    if has_message:
        _require_columns(message_cols, MESSAGE_COLUMNS, "message")

    has_archived = "time_archived" in session_cols
    archived_sql = ", time_archived" if has_archived else ", NULL AS time_archived"
    try:
        sessions = conn.execute(
            "SELECT id, project_id, time_created, time_updated%s FROM session" % archived_sql
        ).fetchall()
        projects = conn.execute("SELECT id FROM project").fetchall()
        messages: List[Tuple[str, str]] = []
        if has_message:
            messages = conn.execute("SELECT id, session_id FROM message").fetchall()
    except sqlite3.Error as exc:
        raise CleanupError("database read failed: %s" % exc) from exc

    session_ids = set()
    session_projects = set()
    session_rows = []
    for sid, project_id, created, updated, archived in sessions:
        sid = _require_loaded_id("session", sid)
        project_id = _require_loaded_id("project", project_id)
        if created is None or updated is None:
            raise CleanupError("session %s has null timestamps" % sid)
        for label, stamp in (("time_created", created), ("time_updated", updated)):
            if type(stamp) is not int or stamp < MIN_MS_TIMESTAMP:
                raise CleanupError(
                    "session %s %s is not unix milliseconds; refusing to guess the unit" % (sid, label)
                )
        session_ids.add(sid)
        session_projects.add(project_id)
        session_rows.append(
            {
                "id": sid,
                "project_id": project_id,
                "time_updated": updated,
                "time_archived": archived,
            }
        )

    project_ids = set()
    for (pid,) in projects:
        project_ids.add(_require_loaded_id("project", pid))

    message_ids = set()
    for mid, sid in messages:
        message_ids.add(_require_loaded_id("message", mid))
        sid = _require_loaded_id("session", sid)
        if sid not in session_ids:
            raise CleanupError("message references a missing session; refusing inconsistent database")

    return {
        "session_ids": session_ids,
        "project_ids": project_ids,
        "session_projects": session_projects,
        "message_ids": message_ids,
        "has_message": has_message,
        "sessions": session_rows,
    }


def _rel(*parts: str) -> str:
    return "/".join(parts)


def _inside(root: str, relpath: str) -> str:
    if not relpath or os.path.isabs(relpath) or relpath.startswith("/") or "\\" in relpath:
        raise CleanupError("manifest path is not a relative data-dir path: %s" % relpath)
    parts = relpath.split("/")
    if any(part in ("", ".", "..") for part in parts):
        raise CleanupError("manifest path escapes the data dir: %s" % relpath)
    root_real = os.path.realpath(root)
    cursor = root_real
    for part in parts:
        cursor = os.path.join(cursor, part)
        if os.path.islink(cursor):
            raise CleanupError("symlink in cleanup path: %s" % relpath)
    full = os.path.realpath(os.path.join(root_real, *parts))
    if full != root_real and not full.startswith(root_real + os.sep):
        raise CleanupError("manifest path escapes the data dir: %s" % relpath)
    return full


def _stamp_old(st: os.stat_result, now: int, protect: int) -> bool:
    return st.st_mtime <= now - protect


def _file_entry(root: str, relpath: str) -> Tuple[str, int, int, int]:
    full = _inside(root, relpath)
    st = os.lstat(full)
    if os.path.islink(full):
        raise CleanupError("symlink")
    if not os.path.isfile(full):
        raise CleanupError("not a file")
    if st.st_nlink != 1:
        raise CleanupError("hardlink")
    return ("f", st.st_size, st.st_mtime_ns, st.st_ino)


def _tree_entries(root: str, relpath: str) -> List[Tuple[str, str, int, int, int]]:
    """List a tree without following links. Raises CleanupError('symlink'|'hardlink')."""
    base = _inside(root, relpath)
    st = os.lstat(base)
    if os.path.islink(base) or not os.path.isdir(base):
        raise CleanupError("symlink" if os.path.islink(base) else "not a directory")
    entries = [("d", relpath, 0, st.st_mtime_ns, st.st_ino)]
    for dirpath, dirnames, filenames in os.walk(base, followlinks=False):
        dirnames.sort()
        filenames.sort()
        for name in dirnames:
            full = os.path.join(dirpath, name)
            if os.path.islink(full):
                raise CleanupError("symlink")
            dst = os.lstat(full)
            rel = os.path.relpath(full, os.path.realpath(root)).replace(os.sep, "/")
            entries.append(("d", rel, 0, dst.st_mtime_ns, dst.st_ino))
        for name in filenames:
            full = os.path.join(dirpath, name)
            if os.path.islink(full):
                raise CleanupError("symlink")
            fst = os.lstat(full)
            if not os.path.isfile(full):
                raise CleanupError("unsupported node")
            if fst.st_nlink != 1:
                raise CleanupError("hardlink")
            rel = os.path.relpath(full, os.path.realpath(root)).replace(os.sep, "/")
            entries.append(("f", rel, fst.st_size, fst.st_mtime_ns, fst.st_ino))
    entries.sort()
    return entries


def _fingerprint_entries(entries: Sequence[Tuple]) -> str:
    blob = json.dumps(entries, separators=(",", ":")).encode()
    return hashlib.sha256(blob).hexdigest()


def _candidate(relpath: str, kind: str, reason: str, entries: Sequence[Tuple]) -> Dict[str, object]:
    nbytes = sum(item[2] for item in entries if item[0] == "f")
    root_entry = entries[0]
    return {
        "relpath": relpath,
        "kind": kind,
        "reason": reason,
        "bytes": nbytes,
        "mtime_ns": root_entry[3] if kind == "tree" else entries[0][2],
        "inode": root_entry[4] if kind == "tree" else entries[0][3],
        "tree_fingerprint": _fingerprint_entries(entries),
    }


def _file_candidate(root: str, relpath: str, reason: str) -> Dict[str, object]:
    kind, size, mtime_ns, inode = _file_entry(root, relpath)
    entries = [(kind, relpath, size, mtime_ns, inode)]
    return {
        "relpath": relpath,
        "kind": "file",
        "reason": reason,
        "bytes": size,
        "mtime_ns": mtime_ns,
        "inode": inode,
        "tree_fingerprint": _fingerprint_entries(entries),
    }


def _newest_mtime(root: str, relpath: str) -> float:
    base = _inside(root, relpath)
    newest = os.lstat(base).st_mtime
    if os.path.isfile(base):
        return newest
    for dirpath, dirnames, filenames in os.walk(base, followlinks=False):
        newest = max(newest, os.lstat(dirpath).st_mtime)
        for name in dirnames + filenames:
            full = os.path.join(dirpath, name)
            if os.path.islink(full):
                raise CleanupError("symlink")
            newest = max(newest, os.lstat(full).st_mtime)
    return newest


class Scan:
    def __init__(self) -> None:
        self.candidates: List[Dict[str, object]] = []
        self.retained: Dict[str, int] = {}
        self.session_age_review: List[str] = []

    def keep(self, reason: str, count: int = 1) -> None:
        self.retained[reason] = self.retained.get(reason, 0) + count


def _children(path: str) -> List[str]:
    try:
        names = os.listdir(path)
    except OSError as exc:
        raise CleanupError("cannot list %s: %s" % (path, exc)) from exc
    return sorted(name for name in names if name != ".DS_Store")


def _scan_session_diff(scan: Scan, root: str, db: Dict[str, object], now: int, protect: int) -> None:
    base = os.path.join(root, "storage", "session_diff")
    if not os.path.isdir(base):
        return
    session_ids = db["session_ids"]
    for name in _children(base):
        rel = _rel("storage", "session_diff", name)
        full = os.path.join(base, name)
        if os.path.islink(full) or not os.path.isfile(full):
            scan.keep("unsupported layout")
            continue
        stem, ext = os.path.splitext(name)
        if ext != ".json" or SESSION_ID.fullmatch(stem) is None:
            scan.keep("unsupported layout")
            continue
        if stem in session_ids:
            scan.keep("known session")
            continue
        st = os.lstat(full)
        if st.st_nlink != 1:
            scan.keep("hardlink")
            continue
        if not _stamp_old(st, now, protect):
            scan.keep("concurrent mtime")
            continue
        scan.candidates.append(
            _file_candidate(root, rel, "session id not in session table")
        )


def _dir_is_flat_files(path: str, pattern) -> Optional[str]:
    """Return a retain reason if the directory is not a flat set of matching files."""
    try:
        names = _children(path)
    except CleanupError:
        return "unsupported layout"
    for name in names:
        full = os.path.join(path, name)
        if os.path.islink(full) or not os.path.isfile(full):
            return "symlink" if os.path.islink(full) else "unsupported layout"
        st = os.lstat(full)
        if st.st_nlink != 1:
            return "hardlink"
        stem, ext = os.path.splitext(name)
        if ext != ".json" or pattern.fullmatch(stem) is None:
            return "unsupported layout"
    return None


def _consider_tree(
    scan: Scan,
    root: str,
    relpath: str,
    reason: str,
    now: int,
    protect: int,
) -> None:
    try:
        if _newest_mtime(root, relpath) > now - protect:
            scan.keep("concurrent mtime")
            return
        entries = _tree_entries(root, relpath)
    except CleanupError as exc:
        code = str(exc)
        if code in ("symlink", "hardlink"):
            scan.keep(code)
        else:
            scan.keep("unsupported layout")
        return
    scan.candidates.append(_candidate(relpath, "tree", reason, entries))


def _scan_message_dirs(scan: Scan, root: str, db: Dict[str, object], now: int, protect: int) -> None:
    base = os.path.join(root, "storage", "message")
    if not os.path.isdir(base):
        return
    if not db["has_message"]:
        scan.keep("unsupported layout", max(1, len(_children(base))))
        return
    for name in _children(base):
        full = os.path.join(base, name)
        rel = _rel("storage", "message", name)
        if os.path.islink(full) or not os.path.isdir(full):
            scan.keep("unsupported layout")
            continue
        if SESSION_ID.fullmatch(name) is None:
            scan.keep("unsupported layout")
            continue
        if name in db["session_ids"]:
            scan.keep("known session")
            continue
        bad = _dir_is_flat_files(full, MESSAGE_ID)
        if bad:
            scan.keep(bad)
            continue
        _consider_tree(scan, root, rel, "session id not in session table", now, protect)


def _scan_part_dirs(
    scan: Scan,
    root: str,
    db: Dict[str, object],
    now: int,
    protect: int,
    allow_empty_messages: bool,
) -> None:
    base = os.path.join(root, "storage", "part")
    if not os.path.isdir(base):
        return
    # Part directories are named by message id. An empty message table cannot
    # distinguish "every part is orphan" from "the read did not return rows".
    if not db["has_message"] or (not db["message_ids"] and not allow_empty_messages):
        scan.keep("unsupported layout", max(1, len(_children(base))))
        return
    for name in _children(base):
        full = os.path.join(base, name)
        rel = _rel("storage", "part", name)
        if os.path.islink(full) or not os.path.isdir(full):
            scan.keep("unsupported layout")
            continue
        # part/<sessionId>/ is the old skill's layout. Message ids are msg_*.
        if MESSAGE_ID.fullmatch(name) is None:
            scan.keep("unsupported layout")
            continue
        if name in db["message_ids"]:
            scan.keep("known message")
            continue
        bad = _dir_is_flat_files(full, PART_ID)
        if bad:
            scan.keep(bad)
            continue
        _consider_tree(scan, root, rel, "message id not in message table", now, protect)


def _scan_session_files(scan: Scan, root: str, db: Dict[str, object], now: int, protect: int) -> None:
    base = os.path.join(root, "storage", "session")
    if not os.path.isdir(base):
        return
    for project in _children(base):
        proj_path = os.path.join(base, project)
        if os.path.islink(proj_path) or not os.path.isdir(proj_path) or not _safe_key(project):
            scan.keep("unsupported layout")
            continue
        for name in _children(proj_path):
            full = os.path.join(proj_path, name)
            rel = _rel("storage", "session", project, name)
            if os.path.islink(full) or not os.path.isfile(full):
                scan.keep("unsupported layout")
                continue
            stem, ext = os.path.splitext(name)
            if ext != ".json" or SESSION_ID.fullmatch(stem) is None:
                scan.keep("unsupported layout")
                continue
            if stem in db["session_ids"]:
                scan.keep("known session")
                continue
            st = os.lstat(full)
            if st.st_nlink != 1:
                scan.keep("hardlink")
                continue
            if not _stamp_old(st, now, protect):
                scan.keep("concurrent mtime")
                continue
            scan.candidates.append(_file_candidate(root, rel, "session id not in session table"))


def _is_snapshot_tree(path: str) -> bool:
    """True for a legacy git dir (HEAD/objects at top) or nested worktree git dirs."""
    names = _children(path)
    if not names:
        return False
    top_files = []
    top_dirs = []
    for name in names:
        full = os.path.join(path, name)
        if os.path.islink(full):
            return False
        if os.path.isdir(full):
            top_dirs.append(full)
        elif os.path.isfile(full):
            top_files.append(name)
        else:
            return False
    if "HEAD" in top_files or "objects" in [os.path.basename(p) for p in top_dirs]:
        return True
    if top_files:
        return False
    if not top_dirs:
        return False
    for child in top_dirs:
        kids = set(_children(child))
        if "HEAD" not in kids and "objects" not in kids:
            return False
    return True


def _scan_snapshots(scan: Scan, root: str, db: Dict[str, object], now: int, protect: int) -> None:
    base = os.path.join(root, "snapshot")
    if not os.path.isdir(base):
        return
    known = set(db["project_ids"]) | set(db["session_projects"])
    for name in _children(base):
        full = os.path.join(base, name)
        rel = _rel("snapshot", name)
        if os.path.islink(full) or not os.path.isdir(full) or not _safe_key(name):
            scan.keep("unsupported layout")
            continue
        if name in known:
            scan.keep("known project")
            continue
        if PROJECT_SHAPE.fullmatch(name) is None or not _is_snapshot_tree(full):
            scan.keep("unsupported layout")
            continue
        _consider_tree(
            scan,
            root,
            rel,
            "project id not in project or session tables",
            now,
            protect,
        )


def _scan_logs(scan: Scan, root: str, now: int, protect: int, log_days: Optional[int]) -> None:
    base = os.path.join(root, "log")
    if not os.path.isdir(base):
        return
    if log_days is None:
        scan.keep("log retention not requested", max(1, len(_children(base)) or 1))
        return
    cutoff = now - log_days * 86400
    for name in _children(base):
        full = os.path.join(base, name)
        rel = _rel("log", name)
        if os.path.islink(full) or not os.path.isfile(full) or LOG_NAME.fullmatch(name) is None:
            scan.keep("unsupported layout")
            continue
        st = os.lstat(full)
        if st.st_nlink != 1:
            scan.keep("hardlink")
            continue
        if st.st_mtime > cutoff or not _stamp_old(st, now, protect):
            scan.keep("log inside retention" if st.st_mtime > cutoff else "concurrent mtime")
            continue
        scan.candidates.append(_file_candidate(root, rel, "log older than retention"))


def _note_skipped(scan: Scan, root: str) -> None:
    for name in DB_NAMES:
        if os.path.lexists(os.path.join(root, name)):
            scan.keep("protected name")
    storage = os.path.join(root, "storage")
    if os.path.isdir(storage):
        for name in SKIPPED_STORAGE:
            if os.path.lexists(os.path.join(storage, name)):
                scan.keep("not a cleanup target")


def _age_review(db: Dict[str, object], now: int, protect: int, days: Optional[int]) -> List[str]:
    if days is None:
        return []
    cutoff_ms = (now - days * 86400) * 1000
    protect_ms = (now - protect) * 1000
    ids = []
    for row in db["sessions"]:
        updated = row["time_updated"]
        if not isinstance(updated, int):
            continue
        if updated >= cutoff_ms or updated >= protect_ms:
            continue
        ids.append(row["id"])
    return sorted(ids)


def _guard_empty(db: Dict[str, object], scan: Scan, allow_sessions: bool, allow_projects: bool) -> None:
    session_file_reasons = {"session id not in session table"}
    if not db["session_ids"] and not allow_sessions:
        if any(item["reason"] in session_file_reasons for item in scan.candidates):
            raise CleanupError(
                "session table is empty and orphan files exist; refusing to treat every blob as orphan. "
                "Pass --allow-empty-sessions only after reviewing that the database read is complete"
            )
    project_reasons = {"project id not in project or session tables"}
    known_projects = set(db["project_ids"]) | set(db["session_projects"])
    if not known_projects and not allow_projects:
        if any(item["reason"] in project_reasons for item in scan.candidates):
            raise CleanupError(
                "project table is empty and snapshot trees exist; refusing to treat every snapshot as stale. "
                "Pass --allow-empty-projects only after reviewing that the database read is complete"
            )


def scan_data(
    root: str,
    now: int,
    protect: int,
    log_days: Optional[int],
    session_days: Optional[int],
    allow_sessions: bool,
    allow_projects: bool,
    allow_messages: bool,
) -> Tuple[Scan, Dict[str, object]]:
    if protect < 0:
        raise CleanupError("protect-mtime-seconds must be >= 0")
    if log_days is not None and log_days < 1:
        raise CleanupError("log-retention-days must be >= 1")
    if session_days is not None and session_days < 1:
        raise CleanupError("session-retention-days must be >= 1")
    db_path = os.path.join(root, "opencode.db")
    for rel in ("storage", "storage/session_diff", "storage/message", "storage/part",
                "storage/session", "snapshot", "log"):
        _inside(root, rel)
    conn = _connect(db_path)
    try:
        db = _load(conn)
    finally:
        conn.close()
    scan = Scan()
    _note_skipped(scan, root)
    _scan_session_diff(scan, root, db, now, protect)
    _scan_message_dirs(scan, root, db, now, protect)
    _scan_part_dirs(scan, root, db, now, protect, allow_messages)
    _scan_session_files(scan, root, db, now, protect)
    _scan_snapshots(scan, root, db, now, protect)
    _scan_logs(scan, root, now, protect, log_days)
    _guard_empty(db, scan, allow_sessions, allow_projects)
    scan.candidates.sort(key=lambda item: str(item["relpath"]))
    scan.session_age_review = _age_review(db, now, protect, session_days)
    return scan, db


def _options(
    protect: int,
    log_days: Optional[int],
    session_days: Optional[int],
    allow_sessions: bool,
    allow_projects: bool,
    allow_messages: bool,
) -> Dict[str, object]:
    return {
        "protect_mtime_seconds": protect,
        "log_retention_days": log_days,
        "session_retention_days": session_days,
        "allow_empty_sessions": allow_sessions,
        "allow_empty_projects": allow_projects,
        "allow_empty_messages": allow_messages,
    }


def _payload(
    data_dir: str,
    options: Dict[str, object],
    db: Dict[str, object],
    scan: Scan,
) -> Dict[str, object]:
    return {
        "version": MANIFEST_VERSION,
        "data_dir": os.path.realpath(data_dir),
        "options": options,
        "session_count": len(db["session_ids"]),
        "project_count": len(db["project_ids"]),
        "message_count": len(db["message_ids"]),
        "candidates": scan.candidates,
        "session_age_review": scan.session_age_review,
        "retained_counts": scan.retained,
    }


def fingerprint(payload: Dict[str, object]) -> str:
    blob = json.dumps(payload, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(blob).hexdigest()


def _write_manifest(path: str, manifest: Dict[str, object]) -> None:
    target = os.path.realpath(path)
    root = os.path.realpath(str(manifest["data_dir"]))
    lexical_target = os.path.abspath(path)
    if (os.path.commonpath((root, target)) == root
            or os.path.commonpath((root, lexical_target)) == root
            or os.path.islink(path)):
        raise CleanupError("manifest must be outside the OpenCode data directory")
    parent = os.path.dirname(os.path.abspath(path)) or "."
    fd, tmp = tempfile.mkstemp(prefix=".manifest-", dir=parent)
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(manifest, handle, indent=2, sort_keys=True)
            handle.write("\n")
        os.replace(tmp, path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def _read_manifest(path: str) -> Dict[str, object]:
    try:
        with open(path, "r") as handle:
            data = json.load(handle)
    except (OSError, json.JSONDecodeError) as exc:
        raise CleanupError("manifest is unreadable: %s" % exc) from exc
    if not isinstance(data, dict):
        raise CleanupError("manifest is not an object")
    if data.get("version") != MANIFEST_VERSION:
        raise CleanupError("unsupported manifest version")
    for key in ("data_dir", "options", "candidates", "fingerprint", "approved"):
        if key not in data:
            raise CleanupError("manifest missing %s" % key)
    if not isinstance(data["candidates"], list):
        raise CleanupError("manifest candidates is not a list")
    if not isinstance(data["approved"], bool):
        raise CleanupError("manifest approved must be a boolean")
    return data


def _payload_from_manifest(manifest: Dict[str, object]) -> Dict[str, object]:
    return {
        "version": manifest["version"],
        "data_dir": manifest["data_dir"],
        "options": manifest["options"],
        "session_count": manifest["session_count"],
        "project_count": manifest["project_count"],
        "message_count": manifest["message_count"],
        "candidates": manifest["candidates"],
        "session_age_review": manifest.get("session_age_review", []),
        "retained_counts": manifest.get("retained_counts", {}),
    }


def cmd_preview(args: argparse.Namespace) -> int:
    root = os.path.realpath(args.data_dir)
    if not os.path.isdir(root):
        raise CleanupError("data dir does not exist: %s" % args.data_dir)
    now = int(args.now if args.now is not None else time.time())
    options = _options(
        args.protect_mtime_seconds,
        args.log_retention_days,
        args.session_retention_days,
        args.allow_empty_sessions,
        args.allow_empty_projects,
        args.allow_empty_messages,
    )
    scan, db = scan_data(
        root,
        now,
        args.protect_mtime_seconds,
        args.log_retention_days,
        args.session_retention_days,
        args.allow_empty_sessions,
        args.allow_empty_projects,
        args.allow_empty_messages,
    )
    payload = _payload(root, options, db, scan)
    token = fingerprint(payload)
    manifest = dict(payload)
    manifest["approved"] = False
    manifest["fingerprint"] = token
    _write_manifest(args.manifest, manifest)
    summary = {
        "ok": True,
        "manifest": os.path.abspath(args.manifest),
        "fingerprint": token,
        "approved": False,
        "candidates": len(scan.candidates),
        "candidate_bytes": sum(int(item["bytes"]) for item in scan.candidates),
        "retained_counts": scan.retained,
        "session_age_review": len(scan.session_age_review),
    }
    json.dump(summary, sys.stdout, sort_keys=True)
    sys.stdout.write("\n")
    return 0


def _same_candidates(fresh: Scan, manifest: Dict[str, object], db: Dict[str, object]) -> None:
    if len(db["session_ids"]) != manifest["session_count"]:
        raise CleanupError("session set changed since preview; refusing stale manifest")
    if len(db["project_ids"]) != manifest["project_count"]:
        raise CleanupError("project set changed since preview; refusing stale manifest")
    if len(db["message_ids"]) != manifest["message_count"]:
        raise CleanupError("message set changed since preview; refusing stale manifest")
    fresh_payload_candidates = json.dumps(fresh.candidates, sort_keys=True, separators=(",", ":"))
    old = json.dumps(manifest["candidates"], sort_keys=True, separators=(",", ":"))
    if fresh_payload_candidates != old:
        raise CleanupError("candidate set changed since preview; refusing stale manifest")
    if fresh.session_age_review != manifest.get("session_age_review", []):
        raise CleanupError("session age review changed since preview; refusing stale manifest")


def _remove_candidate(root: str, item: Dict[str, object]) -> None:
    relpath = str(item["relpath"])
    full = _inside(root, relpath)
    kind = item["kind"]
    if kind == "file":
        if os.path.islink(full) or not os.path.isfile(full):
            raise CleanupError("candidate changed type before delete: %s" % relpath)
        os.unlink(full)
        return
    if kind != "tree":
        raise CleanupError("unknown candidate kind")
    if os.path.islink(full) or not os.path.isdir(full):
        raise CleanupError("candidate changed type before delete: %s" % relpath)
    for dirpath, dirnames, filenames in os.walk(full, topdown=False, followlinks=False):
        for name in filenames:
            path = os.path.join(dirpath, name)
            if os.path.islink(path):
                raise CleanupError("symlink appeared during delete: %s" % relpath)
            os.unlink(path)
        for name in dirnames:
            path = os.path.join(dirpath, name)
            if os.path.islink(path):
                raise CleanupError("symlink appeared during delete: %s" % relpath)
            os.rmdir(path)
    os.rmdir(full)


def cmd_approve(args: argparse.Namespace) -> int:
    manifest = _read_manifest(args.manifest)
    token = fingerprint(_payload_from_manifest(manifest))
    if token != manifest["fingerprint"]:
        raise CleanupError("manifest fingerprint does not match its contents")
    if token != args.expect:
        raise CleanupError("expect does not match manifest fingerprint")
    manifest["approved"] = True
    _write_manifest(args.manifest, manifest)
    json.dump({"ok": True, "approved": True, "fingerprint": token}, sys.stdout, sort_keys=True)
    sys.stdout.write("\n")
    return 0


def cmd_apply(args: argparse.Namespace) -> int:
    if not args.offline:
        raise CleanupError("apply requires --offline: stop all OpenCode writers first")
    manifest = _read_manifest(args.manifest)
    token = fingerprint(_payload_from_manifest(manifest))
    if token != manifest["fingerprint"]:
        raise CleanupError("manifest fingerprint does not match its contents")
    if token != args.expect:
        raise CleanupError("expect does not match manifest fingerprint")
    if manifest["approved"] is not True:
        raise CleanupError("manifest is not approved")
    root = manifest["data_dir"]
    if not isinstance(root, str) or not os.path.isdir(root):
        raise CleanupError("manifest data_dir is not a directory")
    # Re-resolve and require the stored path to already be canonical.
    if os.path.realpath(root) != root:
        raise CleanupError("manifest data_dir is not canonical")
    options = manifest["options"]
    if not isinstance(options, dict):
        raise CleanupError("manifest options is not an object")
    now = int(args.now if args.now is not None else time.time())
    scan, db = scan_data(
        root,
        now,
        int(options["protect_mtime_seconds"]),
        options["log_retention_days"],
        options["session_retention_days"],
        bool(options["allow_empty_sessions"]),
        bool(options["allow_empty_projects"]),
        bool(options.get("allow_empty_messages", False)),
    )
    _same_candidates(scan, manifest, db)
    # Identity check once more, then delete. A mismatch here deletes nothing.
    for item in manifest["candidates"]:
        if not isinstance(item, dict) or "relpath" not in item:
            raise CleanupError("candidate entry is malformed")
        relpath = str(item["relpath"])
        _inside(root, relpath)
        if item["kind"] == "file":
            current = _file_candidate(root, relpath, str(item["reason"]))
        elif item["kind"] == "tree":
            current = _candidate(relpath, "tree", str(item["reason"]), _tree_entries(root, relpath))
        else:
            raise CleanupError("unknown candidate kind")
        if current["tree_fingerprint"] != item["tree_fingerprint"] or current["inode"] != item["inode"]:
            raise CleanupError("candidate identity changed: %s" % relpath)
    deleted = []
    try:
        for item in manifest["candidates"]:
            _remove_candidate(root, item)
            deleted.append(item["relpath"])
    except CleanupError as exc:
        raise CleanupError("%s; already removed: %s" % (exc, ", ".join(deleted) or "(none)"))
    except OSError as exc:
        raise CleanupError(
            "delete failed: %s; already removed: %s" % (exc, ", ".join(deleted) or "(none)")
        )
    json.dump(
        {"ok": True, "deleted": deleted, "deleted_count": len(deleted)},
        sys.stdout,
        sort_keys=True,
    )
    sys.stdout.write("\n")
    return 0


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Fail-closed OpenCode storage cleanup")
    sub = parser.add_subparsers(dest="cmd", required=True)

    preview = sub.add_parser("preview", help="Write a manifest. Does not remove files.")
    preview.add_argument("--data-dir", required=True)
    preview.add_argument("--manifest", required=True)
    preview.add_argument("--protect-mtime-seconds", type=int, default=PROTECT_MTIME_SECONDS_DEFAULT)
    preview.add_argument("--log-retention-days", type=int)
    preview.add_argument("--session-retention-days", type=int)
    preview.add_argument("--allow-empty-sessions", action="store_true")
    preview.add_argument("--allow-empty-projects", action="store_true")
    preview.add_argument("--allow-empty-messages", action="store_true")
    preview.add_argument("--now", type=int, help="Unix seconds. Tests pin this; live runs omit it.")
    preview.set_defaults(func=cmd_preview)

    approve = sub.add_parser("approve", help="Mark a reviewed manifest approved. Does not remove files.")
    approve.add_argument("--manifest", required=True)
    approve.add_argument("--expect", required=True, help="Fingerprint shown by preview")
    approve.set_defaults(func=cmd_approve)

    apply_cmd = sub.add_parser("apply", help="Remove paths in an approved, still-current manifest.")
    apply_cmd.add_argument("--manifest", required=True)
    apply_cmd.add_argument("--expect", required=True)
    apply_cmd.add_argument("--offline", action="store_true",
                           help="Confirm all OpenCode processes and other writers are stopped")
    apply_cmd.add_argument("--now", type=int)
    apply_cmd.set_defaults(func=cmd_apply)
    return parser


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = _build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except CleanupError as exc:
        sys.stderr.write("error: %s\n" % exc)
        return 2
    except (OSError, ValueError, TypeError) as exc:
        sys.stderr.write("error: invalid input or inaccessible storage: %s\n" % exc)
        return 2
    except KeyError as exc:
        sys.stderr.write("error: manifest missing %s\n" % exc)
        return 2


if __name__ == "__main__":
    sys.exit(main())

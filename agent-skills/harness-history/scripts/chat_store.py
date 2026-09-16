#!/usr/bin/env python3
"""SQLite store helpers for chat-read.sh. Bind parameters; never interpolate user values."""

from __future__ import annotations

import argparse
import json
import sqlite3
import sys
from pathlib import Path


def connect_ro(path: str) -> sqlite3.Connection:
    db = Path(path)
    if not db.is_file():
        print(f"chat-read: cannot open database: {path}", file=sys.stderr)
        sys.exit(1)
    try:
        con = sqlite3.connect(f"file:{db.resolve()}?mode=ro", uri=True)
    except sqlite3.Error as exc:
        print(f"chat-read: {exc}", file=sys.stderr)
        sys.exit(1)
    con.row_factory = sqlite3.Row
    return con


def contain(hay: str | None, needle: str) -> bool:
    if not needle:
        return True
    return needle.casefold() in (hay or "").casefold()


def print_row(fields: list[str]) -> None:
    print("\t".join(fields))


def t3_list(con: sqlite3.Connection, query: str) -> list[sqlite3.Row]:
    rows = con.execute(
        """
        SELECT thread_id, substr(created_at, 1, 16) AS ts, title,
               coalesce(branch, '') AS branch
        FROM projection_threads
        WHERE deleted_at IS NULL
        ORDER BY updated_at DESC
        """
    ).fetchall()
    return [r for r in rows if contain(r["title"], query) or contain(r["branch"], query)]


def t3_resolve(con: sqlite3.Connection, query: str) -> str:
    by_id = con.execute(
        "SELECT thread_id FROM projection_threads WHERE thread_id = :q AND deleted_at IS NULL",
        {"q": query},
    ).fetchall()
    if by_id:
        return by_id[0]["thread_id"]
    exact = con.execute(
        "SELECT thread_id, substr(created_at, 1, 16) AS ts, title, coalesce(branch, '') AS branch "
        "FROM projection_threads WHERE deleted_at IS NULL AND title = :q "
        "ORDER BY updated_at DESC",
        {"q": query},
    ).fetchall()
    if len(exact) == 1:
        return exact[0]["thread_id"]
    if len(exact) > 1:
        _print_candidates(query, exact)
        sys.exit(1)
    found = t3_list(con, query)
    if len(found) == 1:
        return found[0]["thread_id"]
    _print_candidates(query, found)
    sys.exit(1)


def _print_candidates(query: str, rows: list[sqlite3.Row]) -> None:
    print(f'Found {len(rows)} chats for "{query}", please specify an id:', file=sys.stderr)
    for row in rows:
        print(
            f"{row['thread_id']}\t{row['ts']}\t{row['title']}\t{row['branch']}",
            file=sys.stderr,
        )


def t3_messages(con: sqlite3.Connection, thread_id: str) -> list[sqlite3.Row]:
    return con.execute(
        """
        SELECT created_at, role, text
        FROM projection_thread_messages
        WHERE thread_id = :id
        ORDER BY created_at, message_id
        """,
        {"id": thread_id},
    ).fetchall()


def slice_tail(messages: list[sqlite3.Row], n: int) -> list[sqlite3.Row]:
    if n < 1:
        print("chat-read: N must be a positive integer", file=sys.stderr)
        sys.exit(1)
    if not messages:
        return []
    start = max(0, len(messages) - n)
    while start > 0 and not any(m["role"] == "user" for m in messages[start:]):
        start -= 1
    return messages[start:]


def print_t3_messages(messages: list[sqlite3.Row]) -> None:
    for row in messages:
        print(f"[{row['created_at']}] [{row['role']}] {row['text']}")


def oc_list(con: sqlite3.Connection, query: str) -> list[sqlite3.Row]:
    rows = con.execute(
        """
        SELECT s.id AS thread_id,
               datetime(s.time_created / 1000, 'unixepoch') AS ts,
               s.title AS title,
               coalesce(p.worktree, '') AS worktree,
               coalesce(s.agent, '') AS agent
        FROM session s
        LEFT JOIN project p ON p.id = s.project_id
        WHERE s.time_archived IS NULL
        ORDER BY s.time_created DESC
        """
    ).fetchall()
    return [
        r
        for r in rows
        if contain(r["title"], query) or contain(r["worktree"], query) or contain(r["agent"], query)
    ]


def oc_resolve(con: sqlite3.Connection, query: str) -> str:
    by_id = con.execute("SELECT id FROM session WHERE id = :q", {"q": query}).fetchall()
    if by_id:
        return by_id[0]["id"]
    exact = con.execute(
        """
        SELECT s.id AS thread_id,
               datetime(s.time_created / 1000, 'unixepoch') AS ts,
               s.title AS title,
               coalesce(p.worktree, '') AS worktree,
               coalesce(s.agent, '') AS agent
        FROM session s
        LEFT JOIN project p ON p.id = s.project_id
        WHERE s.title = :q AND s.time_archived IS NULL
        ORDER BY s.time_created DESC
        """,
        {"q": query},
    ).fetchall()
    if len(exact) == 1:
        return exact[0]["thread_id"]
    if len(exact) > 1:
        _print_oc_candidates(query, exact)
        sys.exit(1)
    found = oc_list(con, query)
    if len(found) == 1:
        return found[0]["thread_id"]
    _print_oc_candidates(query, found)
    sys.exit(1)


def _print_oc_candidates(query: str, rows: list[sqlite3.Row]) -> None:
    print(f'Found {len(rows)} chats for "{query}", please specify an id:', file=sys.stderr)
    for row in rows:
        print(
            f"{row['thread_id']}\t{row['ts']}\t{row['title']}\t{row['worktree']}\t{row['agent']}",
            file=sys.stderr,
        )


def oc_parts(con: sqlite3.Connection, session_id: str) -> list[tuple[str, str, str, str, str]]:
    """Return (created_iso, role, part_type, payload_json, message_id) in order."""
    rows = con.execute(
        """
        SELECT datetime(m.time_created / 1000, 'unixepoch') AS ts,
               json_extract(m.data, '$.role') AS role,
               json_extract(p.data, '$.type') AS ptype,
               p.data AS data,
               m.id AS message_id
        FROM message m
        JOIN part p ON p.message_id = m.id
        WHERE m.session_id = :id
        ORDER BY m.time_created, p.time_created
        """,
        {"id": session_id},
    ).fetchall()
    return [
        (r["ts"] or "", r["role"] or "", r["ptype"] or "", r["data"] or "{}", r["message_id"] or "")
        for r in rows
    ]


def slice_oc_tail(
    parts: list[tuple[str, str, str, str, str]], n: int
) -> list[tuple[str, str, str, str, str]]:
    if n < 1:
        print("chat-read: N must be a positive integer", file=sys.stderr)
        sys.exit(1)
    groups: list[list[tuple[str, str, str, str, str]]] = []
    current_id: str | None = None
    for part in parts:
        mid = part[4]
        if current_id is None or mid != current_id:
            groups.append([part])
            current_id = mid
        else:
            groups[-1].append(part)
    if not groups:
        return []
    start = max(0, len(groups) - n)

    def has_user(gs: list[list[tuple[str, str, str, str, str]]]) -> bool:
        return any(p[1] == "user" and p[2] == "text" for g in gs for p in g)

    while start > 0 and not has_user(groups[start:]):
        start -= 1
    out: list[tuple[str, str, str, str, str]] = []
    for group in groups[start:]:
        out.extend(group)
    return out


def main() -> None:
    parser = argparse.ArgumentParser(prog="chat_store.py")
    parser.add_argument("action", choices=[
        "t3-list", "t3-get", "t3-last",
        "oc-list", "oc-get", "oc-last",
    ])
    parser.add_argument("db")
    parser.add_argument("query", nargs="?", default="")
    parser.add_argument("n", nargs="?", default="20")
    args = parser.parse_args()
    con = connect_ro(args.db)
    try:
        if args.action == "t3-list":
            for row in t3_list(con, args.query):
                print_row([row["thread_id"], row["ts"], row["title"], row["branch"]])
        elif args.action == "t3-get":
            thread_id = t3_resolve(con, args.query)
            print_t3_messages(t3_messages(con, thread_id))
        elif args.action == "t3-last":
            thread_id = t3_resolve(con, args.query)
            try:
                n = int(args.n)
            except ValueError:
                print("chat-read: N must be a positive integer", file=sys.stderr)
                sys.exit(1)
            print_t3_messages(slice_tail(t3_messages(con, thread_id), n))
        elif args.action == "oc-list":
            for row in oc_list(con, args.query):
                print_row([row["thread_id"], row["ts"], row["title"], row["worktree"], row["agent"]])
        elif args.action == "oc-get":
            session_id = oc_resolve(con, args.query)
            _print_oc_parts(oc_parts(con, session_id), timestamps=True)
        elif args.action == "oc-last":
            session_id = oc_resolve(con, args.query)
            try:
                n = int(args.n)
            except ValueError:
                print("chat-read: N must be a positive integer", file=sys.stderr)
                sys.exit(1)
            _print_oc_parts(slice_oc_tail(oc_parts(con, session_id), n), timestamps=True)
    except sqlite3.Error as exc:
        print(f"chat-read: {exc}", file=sys.stderr)
        sys.exit(1)
    finally:
        con.close()


def _print_oc_parts(parts: list[tuple[str, str, str, str, str]], timestamps: bool) -> None:
    for ts, role, ptype, data, _message_id in parts:
        prefix = f"[{ts}] " if timestamps and ts else ""
        try:
            payload = json.loads(data) if data else {}
        except json.JSONDecodeError:
            payload = {}
        if ptype == "text":
            text = payload.get("text", "")
            print(f"{prefix}[{role}] {text}")
        elif ptype == "tool":
            tool = payload.get("tool", "")
            print(f"{prefix}## tool {tool}")
            state = payload.get("state") or {}
            inp = str(state.get("input") or "")[:400]
            out = str(state.get("output") or "")[:800]
            if inp:
                print(inp)
            if out:
                print(out)
        elif ptype == "file":
            print(f"{prefix}## file {payload.get('filename') or ''}")
        elif ptype == "compaction":
            print(f"{prefix}**[compaction]**")


if __name__ == "__main__":
    main()

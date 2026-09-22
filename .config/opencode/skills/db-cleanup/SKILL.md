---
name: db-cleanup
description: Clean up OpenCode storage with a fail-closed preview and an approved manifest. Use when the user asks to shrink the OpenCode data directory, remove orphaned OpenCode session files, or reclaim OpenCode snapshot or log space.
---

# OpenCode storage cleanup

Remove orphaned OpenCode files only through `~/.config/opencode/skills/db-cleanup/scripts/cleanup.py`. The helper reads `opencode.db` read-only, checks the layout, and writes a manifest. Preview does not remove files. Apply removes a path only when that manifest is approved and a fresh read still describes the same path.

A refused helper run is the result. Report stderr and stop.

## Layout

OpenCode 1.18.32 keeps sessions in SQLite (`session.id` like `ses_…`, `project.id` a 40-hex git root or `global`, timestamps in unix milliseconds). JSON keys that still sit on disk:

- `storage/session_diff/<sessionId>.json`
- `storage/message/<sessionId>/<messageId>.json`
- `storage/part/<messageId>/<partId>.json` — the directory name is the message id (`msg_…`)
- `storage/session/<projectId>/<sessionId>.json`
- `snapshot/<projectId>/` — legacy git dir, or `<projectId>/<worktreeHash>/`

`storage/migration`, `storage/project`, `storage/todo`, `storage/session_share`, `opencode.db` (and its `-wal` / `-shm`), and credential files stay. A name that does not match a layout above stays. A project id present in `project` or `session` keeps its whole snapshot tree, including a project that currently has no extra sessions.

## Steps

### 1. Locate the data directory

Run `~/.opencode/bin/opencode debug paths` and take the `data` line. Done when that directory exists and contains `opencode.db`.

Use that binary. A `PATH` `opencode` can be an older build with no database command.

### 2. Measure

Record `du -sh` for the data directory, `opencode.db`, `storage/`, and `snapshot/`. Done when the user has that table.

### 3. Retention

Use the retention and cleanup scope already requested. Ask only for missing choices that affect deletion. Logs are excluded by default; the file-age protection window defaults to 86400 seconds. Session-age review is optional because this helper does not delete session rows.

Choose a manifest path outside the OpenCode data directory. The helper refuses to write a manifest inside that directory.

### 4. Preview

```bash
python3 ~/.config/opencode/skills/db-cleanup/scripts/cleanup.py preview \
  --data-dir "$DATA" \
  --manifest "$MANIFEST" \
  --protect-mtime-seconds SECONDS \
  --session-retention-days DAYS
```

Add `--log-retention-days DAYS` only when logs are in scope. Add `--now` only in tests.

Done when the process exits 0, stdout `approved` is false, and the user has the fingerprint, candidate count, candidate bytes, retained counts, and `session_age_review`. A failed scan does not replace the manifest; an older manifest may still exist. Show stderr and stop rather than applying an older result.

`session_age_review` lists old session ids. Apply does not delete those rows or their files.

### 5. Approve

Show the candidate paths and the fingerprint. Done when the user approves that fingerprint.

```bash
python3 ~/.config/opencode/skills/db-cleanup/scripts/cleanup.py approve \
  --manifest "$MANIFEST" --expect FINGERPRINT
```

Done when this exits 0. This still removes nothing.

### 6. Apply

Apply is an offline maintenance operation. All OpenCode servers, clients, scheduled tasks, and other writers to this data directory must be stopped and remain stopped for the run. Use the user's existing authorization for stopping services; ask if stopping an active service was not authorized. The helper requires `--offline` as an operator assertion; it does not detect or stop writers. File-age checks and fresh scans are additional checks, not concurrency locks.

```bash
python3 ~/.config/opencode/skills/db-cleanup/scripts/cleanup.py apply --offline \
  --manifest "$MANIFEST" --expect FINGERPRINT
```

Done when the process exits 0 and stdout lists `deleted`. On a non-zero exit, show stderr and stop. A refusal before deletion leaves the tree unchanged. If deletion fails, the operation may be partial, including within the current tree. The `already removed` list contains completed candidates only. Inspect the current candidate and preview again before any further apply.

### 7. Report

Show candidate bytes removed and a fresh `du` table. Done when the user has the before and after sizes.

Session-row deletion (`~/.opencode/bin/opencode session delete`) and `VACUUM` rewrite the live database. They are a separate confirmation after apply, not part of this helper.
